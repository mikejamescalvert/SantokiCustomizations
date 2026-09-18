// The scheduled job: read new deliveries, check received orders, then create sales orders.
//
// Run it from the job queue every few minutes, or from the Amazon Orders page. Each delivery and
// each order is handled in its own transaction, so one bad order is marked Error and the rest
// carry on.
codeunit 50208 "Amazon Order Job"
{
    trigger OnRun()
    begin
        ReadInbox();
        ProcessOrders(Enum::"Amazon Staging Status"::Received);
        ProcessOrders(Enum::"Amazon Staging Status"::Ready);
    end;

    procedure ReadInbox()
    var
        Inbox: Record "Amazon Order Inbox";
        EntryNos: List of [BigInteger];
        EntryNo: BigInteger;
    begin
        Inbox.SetCurrentKey(Processed, Attempts, "Entry No.");
        Inbox.SetRange(Processed, false);
        Inbox.SetFilter(Attempts, '<%1', MaxInboxAttempts());
        if Inbox.FindSet() then
            repeat
                EntryNos.Add(Inbox."Entry No.");
            until Inbox.Next() = 0;

        foreach EntryNo in EntryNos do
            ReadInboxEntry(EntryNo);
    end;

    procedure ProcessOrders(StatusToProcess: Enum "Amazon Staging Status")
    var
        StagedOrder: Record "Amazon Staged Order";
        OrderIds: List of [Code[30]];
        OrderId: Code[30];
    begin
        StagedOrder.SetCurrentKey(Status, "Purchase Date");
        StagedOrder.SetRange(Status, StatusToProcess);
        if StagedOrder.FindSet() then
            repeat
                OrderIds.Add(StagedOrder."Amazon Order Id");
            until StagedOrder.Next() = 0;

        foreach OrderId in OrderIds do
            ProcessOrder(OrderId);
    end;

    local procedure ReadInboxEntry(EntryNo: BigInteger)
    var
        Inbox: Record "Amazon Order Inbox";
        Succeeded: Boolean;
        ErrorText: Text;
    begin
        if not Inbox.Get(EntryNo) then
            exit;
        Commit();
        ClearLastError();
        Succeeded := Codeunit.Run(Codeunit::"Amazon Order Import", Inbox);
        ErrorText := GetLastErrorText();

        Inbox.Get(EntryNo);
        Inbox.Attempts += 1;
        if Succeeded then begin
            Inbox.Processed := true;
            Inbox."Processed At" := CurrentDateTime();
            Inbox."Error Message" := '';
        end else
            Inbox."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(Inbox."Error Message"));
        Inbox.Modify();
        Commit();
    end;

    local procedure ProcessOrder(OrderId: Code[30])
    var
        StagedOrder: Record "Amazon Staged Order";
        Succeeded: Boolean;
        ErrorText: Text;
    begin
        if not StagedOrder.Get(OrderId) then
            exit;

        // Mark the order before creating anything and commit that, so an interrupted run leaves
        // an In Progress order to check, rather than one that is quietly created a second time.
        if StagedOrder.Status = StagedOrder.Status::Ready then
            StagedOrder.Status := StagedOrder.Status::"In Progress";
        StagedOrder.Attempts += 1;
        StagedOrder."Last Attempt At" := CurrentDateTime();
        StagedOrder.Modify();
        Commit();

        ClearLastError();
        Succeeded := Codeunit.Run(Codeunit::"Amazon Order Processing", StagedOrder);
        ErrorText := GetLastErrorText();

        if not Succeeded then begin
            StagedOrder.Get(OrderId);
            StagedOrder.Status := StagedOrder.Status::Error;
            StagedOrder."Status Message" := CopyStr(ErrorText, 1, MaxStrLen(StagedOrder."Status Message"));
            StagedOrder.Modify();
        end;
        Commit();
    end;

    local procedure MaxInboxAttempts(): Integer
    begin
        exit(3);
    end;
}

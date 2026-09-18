// Where a staged Amazon order is in its journey from Amazon to a Business Central sales order.
// This is the status the team filters on, in place of Suite Engine's Channel Orders screen.
enum 50214 "Amazon Staging Status"
{
    Extensible = false;
    Caption = 'Amazon Staging Status';

    value(0; Received) { Caption = 'Received'; }
    value(1; Ready) { Caption = 'Ready'; }
    value(2; "In Progress") { Caption = 'In Progress'; }
    value(3; Posted) { Caption = 'Posted'; }
    value(4; Error) { Caption = 'Error'; }
    value(5; "On Hold") { Caption = 'On Hold'; }
    value(6; Cancelled) { Caption = 'Cancelled'; }
}

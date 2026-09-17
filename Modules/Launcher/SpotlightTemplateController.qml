import QtQuick
import qs.Services
import "../../Common/functions/SpotlightTemplates.js" as Templates

QtObject {
    id: root
    property string mode: ""
    property string text: ""
    property bool applying: false
    property string expression: ""
    property string sourceZone: ""
    property string targetZone: ""
    property bool choosingSource: false
    property int selected: -1
    readonly property bool timeMode: mode === "time"
    readonly property bool choosingTime: timeMode && (!targetZone || choosingSource)
    readonly property bool active: timeMode
    readonly property string heading: choosingSource ? qsTr("Source time zone") : qsTr("Target time zone")
    readonly property string direction: (sourceZone || qsTr("Local time")) + " → " + targetZone
    readonly property var choices: {
        if (!active || (timeMode && !choosingTime))
            return [];
        const filter = timeMode ? text.trim().toLowerCase() : "";
        const seen = {};
        return SpotlightToolService.candidates.filter(item => {
            if (filter && !(item.text + " " + item.name).toLowerCase().includes(filter))
                return false;
            if (seen[item.text])
                return false;
            seen[item.text] = true;
            return true;
        });
    }
    signal replaceText(string value, int start, int end)

    function write(value, start, end) {
        applying = true;
        replaceText(value, start, end);
        applying = false;
    }
    function reset() {
        selected = -1;
        expression = "";
        choosingSource = false;
        sourceZone = "";
        targetZone = "";
        if (timeMode)
            write("", 0, 0);
    }
    function edit() {
        if (applying || !active)
            return;
        selected = -1;
        expression = choosingTime ? "" : Templates.timeExpression(text, sourceZone, targetZone);
    }

    function move(delta) {
        if (!choices.length)
            return false;
        selected = selected < 0 ? (delta > 0 ? 0 : choices.length - 1) : (selected + delta + choices.length)
                                  % choices.length;
        return true;
    }
    function choose(index) {
        const choice = choices[index];
        if (!choice)
            return false;
        if (choosingSource) {
            sourceZone = choice.text;
            choosingSource = false;
        } else
            targetZone = choice.text;
        write("", 0, 0);
        expression = "";
        selected = -1;
        return true;
    }
    function changeSource() {
        choosingSource = true;
        expression = "";
        write("", 0, 0);
    }
    function backspace() {
        if (!timeMode || text.length || !targetZone || choosingSource)
            return false;
        targetZone = "";
        selected = -1;
        expression = "";
        return true;
    }
    onTextChanged: edit()
    onChoicesChanged: selected = -1
}

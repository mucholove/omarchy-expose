import QtQuick
import QtTest
import "../AgentModel.js" as AgentModel

TestCase {
    name: "AgentModel"

    function test_stateFromTitle() {
        compare(AgentModel.stateFromTitle("✳ Android Health Connect"), "waiting");
        compare(AgentModel.stateFromTitle("◑ Omarchy-expose"), "working");
        compare(AgentModel.stateFromTitle("⠋ thinking"), "working");
        compare(AgentModel.stateFromTitle("5 Linux to main"), "");
        compare(AgentModel.stateFromTitle(""), "");
    }

    function test_cleanTitle() {
        compare(AgentModel.cleanTitle("✳ Android Health Connect"), "Android Health Connect");
        compare(AgentModel.cleanTitle("◑ Omarchy-expose"), "Omarchy-expose");
        compare(AgentModel.cleanTitle("5 Linux to main"), "5 Linux to main");
        compare(AgentModel.cleanTitle("✳"), "✳");
    }

    function test_shortPath() {
        compare(AgentModel.shortPath("/home/me", "/home/me"), "~");
        compare(AgentModel.shortPath("/home/me/Work/kboom", "/home/me"), "~/Work/kboom");
        compare(AgentModel.shortPath("/home/me/Work/kboom/.claude/worktrees/x", "/home/me"), "…/x");
        compare(AgentModel.shortPath("/proc/12/fdinfo", "/home/me"), "");
        compare(AgentModel.shortPath("", "/home/me"), "");
    }

    function test_infoAndLabels() {
        var results = AgentModel.parseResult('{"7":{"agent":"claude","cwd":"/x"}}');
        compare(AgentModel.infoFor(results, 7).agent, "claude");
        compare(AgentModel.infoFor(results, 8).agent, "");
        compare(AgentModel.parseResult("not json").x, undefined);
        compare(AgentModel.labelFor("codex"), "Codex");
        verify(AgentModel.isTerminalClass("kitty"));
        verify(!AgentModel.isTerminalClass("chromium"));
    }
}

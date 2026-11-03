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

    function test_folderAndDuration() {
        compare(AgentModel.folderName("/home/me/Work/kboom", "/home/me"), "kboom");
        compare(AgentModel.folderName("/home/me", "/home/me"), "~");
        compare(AgentModel.folderName("/proc/1/fdinfo", "/home/me"), "");
        compare(AgentModel.shortPath("/home/me/a/b/c/d", "/home/me", true), "…/d".length ? "~/a/b/c/d" : "");
        compare(AgentModel.durationText(1000, 1000 + 30), "just now");
        compare(AgentModel.durationText(1000, 1000 + 7 * 60), "7m");
        compare(AgentModel.durationText(1000, 1000 + 2 * 3600 + 5 * 60), "2h 5m");
        compare(AgentModel.durationText(1000, 1000 + 3 * 86400 + 4 * 3600), "3d 4h");
        compare(AgentModel.durationText(0, 1000), "");
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

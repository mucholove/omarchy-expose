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

    function test_sessionTitle() {
        compare(AgentModel.sessionTitle({ name: "kboom-41", nameSource: "derived", title: "Fix follower" }), "Fix follower");
        compare(AgentModel.sessionTitle({ name: "kboom-41", nameSource: "derived", title: "" }), "kboom-41");
        compare(AgentModel.sessionTitle({ name: "My name", nameSource: "user", title: "Fix follower" }), "My name");
        compare(AgentModel.sessionGoal({ name: "My name", nameSource: "user", title: "Fix follower" }), "Fix follower");
        compare(AgentModel.sessionGoal({ name: "x", nameSource: "derived", title: "Fix follower" }), "");
        compare(AgentModel.sessionTitle(null), "");
        compare(AgentModel.sessionGoal({ name: "x", nameSource: "derived", title: "T", recap: "Goal: ship it. Next: test." }), "ship it. Next: test.");
    }

    function test_worktreeFreeing() {
        var git = { linked: true, dirty: 0, ahead: 1, base: "origin/main" };
        verify(AgentModel.canFreeWorktree({ live: false, git: git, cwdExists: true, liveHere: 0, status: "ended" }));
        verify(!AgentModel.canFreeWorktree({ live: false, git: git, cwdExists: true, liveHere: 1, status: "ended" }));
        verify(AgentModel.canFreeWorktree({ live: true, git: git, cwdExists: true, liveHere: 1, status: "idle" }));
        verify(!AgentModel.canFreeWorktree({ live: true, git: git, cwdExists: true, liveHere: 1, status: "busy" }));
        verify(!AgentModel.canFreeWorktree({ live: true, git: git, cwdExists: true, liveHere: 2, status: "idle" }));
        verify(!AgentModel.canFreeWorktree({ live: false, git: { linked: true, dirty: 2 }, cwdExists: true, liveHere: 0 }));
        verify(!AgentModel.canFreeWorktree({ live: false, git: { linked: false, dirty: 0 }, cwdExists: true, liveHere: 0 }));
        verify(!AgentModel.canFreeWorktree({ live: false, git: git, cwdExists: false, liveHere: 0 }));
        compare(AgentModel.bytesText(6442160356), "6.4 GB");
        compare(AgentModel.bytesText(11000000000), "11 GB");
        compare(AgentModel.bytesText(820000000), "820 MB");
        compare(AgentModel.bytesText(0), "");
        compare(AgentModel.sessionChips({ git: git, sizeBytes: 5e9, cwdExists: true })[0].kind, "unmerged");
        compare(AgentModel.sessionChips({ git: git, sizeBytes: 5e9, cwdExists: true }).slice(-1)[0].text, "▤ 5.0 GB worktree");
        verify(AgentModel.freeSummary({ git: git, branch: "fix/x", sizeBytes: 5e9, live: false }).indexOf("keeps its 1 commit") > 0);
    }

    function test_projectLabel() {
        compare(AgentModel.projectLabel("/h/Work/kboom", { repo: "kboom" }, "/h"), "kboom");
        compare(AgentModel.projectLabel("/h/Work/kboom/.claude/worktrees/linux-edge", { repo: "kboom" }, "/h"), "kboom › linux-edge");
        compare(AgentModel.projectLabel("/h/notes", {}, "/h"), "notes");
        compare(AgentModel.projectLabel("/h", {}, "/h"), "~");
        compare(AgentModel.projectLabel("", { repo: "kboom" }, "/h"), "kboom");
    }

    function test_infoAndLabels() {
        var results = AgentModel.parseResult('{"windows":{"7":{"agent":"claude","cwd":"/x"}}}');
        compare(AgentModel.infoFor(results, 7).agent, "claude");
        compare(AgentModel.infoFor(results, 8).agent, "");
        compare(AgentModel.parseResult("not json").x, undefined);
        compare(AgentModel.labelFor("codex"), "Codex");
        verify(AgentModel.isTerminalClass("kitty"));
        verify(!AgentModel.isTerminalClass("chromium"));
    }

    function test_sessions() {
        var now = 1000000000;
        var results = { sessions: [
            { name: "old", status: "idle", statusAt: now - 3 * 86400000 },
            { name: "wait", status: "idle", statusAt: now - 600000 },
            { name: "busy", status: "busy", statusAt: now - 60000 },
            { name: "wait2", status: "idle", statusAt: now - 60000 }
        ] };
        var rows = AgentModel.sessionRows(results, now);
        compare(rows[0].header, "Working");
        compare(rows[1].session.name, "busy");
        compare(rows[2].header, "Waiting for you");
        compare(rows[3].session.name, "wait2");
        compare(rows[4].session.name, "wait");
        compare(rows[5].header, "Older");
        compare(rows[6].session.name, "old");
        compare(AgentModel.sessionState({ status: "shell" }), "shell");
        compare(AgentModel.tokensText(145978), "146k");
        compare(AgentModel.tokensText(1250000), "1.3M");
        compare(AgentModel.tokensText(0), "");
        compare(AgentModel.modelLabel("claude-opus-5-5"), "Opus 5.5");
        compare(AgentModel.modelLabel("claude-sonnet-5"), "Sonnet 5");
        compare(AgentModel.ageText(1000000, 1000000 + 7 * 60000), "7m");
        compare(AgentModel.sessionRows({}, now).length, 0);
        compare(AgentModel.sessionRows(results, now, { showOlder: false }).length, 5);
        var withEnded = { sessions: results.sessions.concat([
            { name: "gone", status: "ended", statusAt: now - 5 * 86400000 },
            { name: "arch", status: "idle", statusAt: now - 1000, archived: true }
        ]) };
        compare(AgentModel.sessionRows(withEnded, now).length, 9);
        compare(AgentModel.sessionRows(withEnded, now, { showEnded: false }).length, 7);
        var shown = AgentModel.sessionRows(withEnded, now, { showArchived: true });
        compare(shown[shown.length - 2].header, "Archived");
        compare(AgentModel.gitChips({}).length, 0);
        compare(AgentModel.gitChips({ dirty: 0, ahead: 0, base: "origin/main" })[0].text, "✓ all on main");
        var both = AgentModel.gitChips({ dirty: 2, ahead: 3, base: "origin/main" });
        compare(both.length, 2);
        compare(both[0].kind, "dirty");
        compare(both[1].text, "↑ 3 not on main");
        compare(AgentModel.gitChips({ dirty: 0, ahead: 0, base: "" }).length, 0);
    }
}

import QtQuick
import QtTest
import "../../Common/functions/SpotlightSession.js" as Session
import "../../Common/functions/SpotlightCommands.js" as Commands
import "../../Common/functions/SpotlightCompletion.js" as Completion
import "../../Common/functions/SpotlightControlGesture.js" as Gesture
import "../../Common/functions/SpotlightToolResponse.js" as ToolResponse

TestCase {
    name: "SpotlightSession"

    function test_obsoleteToolAnswers() {
        const request = {
            generation: 2,
            instance: 1
        };
        const answer = {
            ok: true,
            error: null,
            answer: "170"
        };
        verify(ToolResponse.copyable(answer, request, true, "valid", 2, 1));
        // Editing input, returning/re-entering a tool and closing invalidate an
        // otherwise valid response even if the backend finishes afterward.
        verify(!ToolResponse.copyable(answer, request, true, "valid", 3, 1));
        verify(!ToolResponse.copyable(answer, request, true, "valid", 2, 2));
        verify(!ToolResponse.copyable(answer, request, false, "valid", 2, 1));
        verify(!ToolResponse.copyable(answer, request, true, "loading", 2, 1));
        verify(!ToolResponse.copyable({
                                          ok: false,
                                          error: {
                                              code: "timeout"
                                          },
                                          answer: "error"
                                      }, request, true, "valid", 2, 1));
    }

    function test_parentAndOverrides() {
        let state = Session.create("apps");
        state = Session.setOverride(state, "appsLayout", "grid", "list");
        state = Session.setOverride(state, "appsOrder", "smart", "name");
        state = Session.input(state, "/calc", false, "app:one");
        const tool = Session.enterTool(state, "calculator", "8/2", true);
        compare(tool.query, "8/2");
        compare(Session.route(tool, "8/2").kind, "query");
        state = Session.pop(tool);
        compare(state.mode, "apps");
        compare(state.query, "");
        compare(state.selectionId, "app:one");
        compare(Session.effective(state, "appsLayout", "list"), "grid");
        compare(Session.effective(state, "appsOrder", "name"), "smart");
        state = Session.pop(state);
        compare(Session.effective(state, "appsOrder", "name"), "name");
        compare(Session.effective(state, "appsLayout", "list"), "grid");
        state = Session.pop(state);
        compare(Session.effective(state, "appsLayout", "list"), "list");
        compare(Session.pop(state), state);
    }

    function test_boundedReplacement() {
        let state = Session.create("apps");
        for (let i = 0; i < 100; ++i)
            state = Session.setOverride(state, "appsLayout", i % 2 ? "grid" : "list", "list");
        compare(state.overrides.length, 1);
        let tool = Session.enterTool(state, "calculator", "", false);
        for (let i = 0; i < 100; ++i)
            tool = Session.enterTool(tool, i % 2 ? "time" : "currency", "", false);
        compare(Session.pop(tool).overrides.length, 1);
        verify(!Session.pop(tool).parent);
        state = Session.setOverride(state, "appsLayout", "list", "list");
        compare(state.overrides.length, 0);
    }

    function test_commandsAndLiteral() {
        const state = Session.create("search");
        compare(Session.route(state, ">calc").query, "calc");
        compare(Session.route(state, "\\/etc").kind, "literal");
        compare(Session.route(state, "\\>hello").query, ">hello");
        compare(Session.route(Session.input(state, "/app", true), "/app").kind, "query");
        verify(Commands.match("", true).every(entry => !!Commands.exact(entry.slashName)));
        verify(Commands.match("", true).every(entry => entry.kind !== "override"));
        compare(Commands.exact("search").value, "web");
        compare(Commands.exact("default").value, "search");
        compare(Commands.exact("clal"), null);
        compare(Commands.resolve("grid", "", state).error, "scope");
        compare(Commands.resolve("light", "extra", state).error, "arguments");
        compare(Commands.resolve("cal", "", state).error, "unknown");
        compare(Commands.resolve("currency", "100 USD to CNY", state).entry.id, "tool.currency");
        const commands = Session.input(Session.create("commands"), "calc", false);
        compare(Session.pop(Session.enterTool(commands, "calculator", "", false)).query, "calc");
    }

    function test_backspaceGuards() {
        const state = Session.enterTool(Session.create("apps"), "calculator", "", false);
        const event = {
            searchFocus: true
        };
        verify(Session.canBackspace(state, event));
        for (const guard of ["selection", "preedit", "modal", "repeat"])
            verify(!Session.canBackspace(state, Object.assign({}, event, {
                                                                  [guard]: true
                                                              })));
        verify(!Session.canBackspace(state, {
                                         searchFocus: false
                                     }));
        verify(!Session.canBackspace(Session.input(state, " ", false), event));
        verify(!Session.canBackspace(Object.assign({}, state, {
                                                       completion: {}
                                                   }), event));
        compare(Session.switchMode(state, "files", true).query, "");
    }

    function test_completionOffsetsAndIdentity() {
        const text = "😀 USD to CN + tail";
        const candidates = Completion.candidates(text, 12, [
                                                     {
                                                         text: "CNY",
                                                         id: "cny"
                                                     }
                                                 ]);
        compare(candidates.length, 1);
        const accepted = Completion.accept(text, candidates[0]);
        compare(accepted.text, "😀 USD to CNY + tail");
        compare(accepted.cursor, 13);
        compare(accepted.selectionId, "cny");
        const names = Completion.candidates("中文", 2, [
                                                {
                                                    text: "中文 😀 App",
                                                    id: "a",
                                                    literal: true
                                                }
                                            ], {
                                                start: 0,
                                                end: 2,
                                                prefix: "中文"
                                            });
        verify(Completion.accept("中文", names[0]).literal);
    }

    function test_controlGesture() {
        const press = {
            eligible: true,
            controlKey: true,
            time: 100
        };
        const release = {
            eligible: true,
            controlKey: true,
            time: 200
        };
        verify(!Gesture.release(Gesture.idle(), release).toggle);
        const pending = Gesture.press(Gesture.idle(), press);
        verify(Gesture.release(pending, release).toggle);
        verify(!Gesture.release(Gesture.hold(pending, 400, true), release).toggle);
        verify(!Gesture.hold(pending, 400, true).pending);
        verify(!Gesture.release(pending, Object.assign({}, release, {
                                                           time: 400
                                                       })).toggle);
        verify(!Gesture.release(Gesture.press(pending, {
                                                  eligible: true,
                                                  controlKey: false
                                              }), release).toggle);
        verify(!Gesture.release(Gesture.press(pending, press), release).toggle);
        verify(!Gesture.release(pending, Object.assign({}, release, {
                                                           eligible: false
                                                       })).toggle);
        verify(!Gesture.release(pending, Object.assign({}, release, {
                                                           repeat: true
                                                       })).toggle);
        verify(Gesture.press(pending, Object.assign({}, press, {
                                                        repeat: true
                                                    })).pending);
        verify(!Gesture.hold(pending, 200, false).pending);
    }
}

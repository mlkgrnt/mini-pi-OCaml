import {
    Loader,
    type Editor,
    type TuiMainScreen,
} from "@earendil-works/pi-tui";
import { cyan_color_wrapper, dim_color_wrapper } from "./theme.js";

export class ActivityLoader {
    private loader: Loader;
    private tui: TuiMainScreen;
    private editor: Editor;

    constructor(tui: TuiMainScreen, editor: Editor) {
        this.tui = tui;
        this.editor = editor;
        this.loader = new Loader(
            tui,
            cyan_color_wrapper,
            dim_color_wrapper,
            "working...",
        );
    }

    public start(status: string = "working...") {
        this.tui.removeChild(this.editor);
        this.tui.removeChild(this.loader);
        this.tui.addChild(this.loader);
        this.tui.addChild(this.editor);

        this.loader.start();
        this.setStatus(status);
    }

    public setStatus(status: string) {
        this.loader.setMessage(status);
        this.tui.requestRender();
    }

    public stop() {
        this.loader.stop();
        this.tui.removeChild(this.loader);
        this.tui.requestRender();
    }
}

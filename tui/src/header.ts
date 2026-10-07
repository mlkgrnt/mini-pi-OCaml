import { Container, HStack, Spacer, Text } from "@earendil-works/pi-tui";
import { cyan_color_wrapper, dim_color_wrapper } from "./theme.js";
import { readFileSync } from "node:fs";

function loadLogo(): string {
    try {
        const logoPath = new URL("./assets/logo.txt", import.meta.url);
        const logo = readFileSync(logoPath, "utf-8").trimEnd();
        return logo;
    } catch {
        return "Mini Pi";
    }
}

export class TUIHeader {
    public headerContainer = new Container();
    public currentModel: string = "";
    public currentSessionId: string = "";
    public logo: string = "";
    public version_str: string = "Mini-Pi 0.1.3";
    public cwd: string;

    public requestRender: () => void;

    constructor(requestRender: () => void) {
        this.requestRender = requestRender;
        this.logo = loadLogo();
        this.cwd = process.cwd().replace(process.env.HOME || "", "~");
    }

    public updateHeader() {
        this.headerContainer.clear();
        const logoText = new Text(cyan_color_wrapper(this.logo), 1, 0);

        const info: string[] = [this.version_str];

        if (this.currentModel) {
            info.push(`model: ${this.currentModel}`);
        }

        info.push(this.cwd);

        if (this.currentSessionId) {
            info.push(`Session ${this.currentSessionId}`);
        }

        const infoText = new Text(dim_color_wrapper(info.join("\n")), 0, 0);

        // Same layout as CSS Flexbox
        // shrink = 0 means dont let this component shrink
        // Logo is 9 column wide so 11 is good enough
        const hstack = new HStack(
            [
                { component: logoText, basis: 11, shrink: 0 },
                { component: infoText },
            ],
            { gap: 2 },
        );

        this.headerContainer.addChild(hstack);
        this.headerContainer.addChild(new Spacer(1));

        this.headerContainer.invalidate();
        this.requestRender();
    }
}

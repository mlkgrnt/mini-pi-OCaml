import type {
    EditorTheme,
    MarkdownTheme,
    SelectListTheme,
} from "@earendil-works/pi-tui";

export type Colorfn = (text: string) => string;

function get_color_wrapper(code: number): Colorfn {
    return (text: string) => `\x1b[${code}m${text}\x1b[0m`;
}

const dim_color_wrapper = get_color_wrapper(90); // Gray / muted (for thinking tokens)
const cyan_color_wrapper = get_color_wrapper(36); // Cyan (for user messages)
const red_color_wrapper = get_color_wrapper(31); // Red (for errors)
const magneta_color_wrapper = get_color_wrapper(35); // Magenta (for tools)

const editorSelectListTheme: SelectListTheme = {
    selectedPrefix: cyan_color_wrapper,
    selectedText: cyan_color_wrapper,
    description: dim_color_wrapper,
    scrollInfo: dim_color_wrapper,
    noMatch: dim_color_wrapper,
};

const editorTheme: EditorTheme = {
    borderColor: dim_color_wrapper,
    selectList: editorSelectListTheme,
};

const mdTheme: MarkdownTheme = {
    heading: get_color_wrapper(1), // bold

    // [Click here](https://example.com)
    link: cyan_color_wrapper,

    // https://example.com
    linkUrl: dim_color_wrapper,

    code: get_color_wrapper(32), // Green, `print("hello")`

    // ```python
    // def foo():
    //     return 42
    // ```
    codeBlock: get_color_wrapper(32),
    codeBlockBorder: dim_color_wrapper,

    // > This is quote sentence
    quote: dim_color_wrapper,
    quoteBorder: dim_color_wrapper,

    // Horizontal rule i.e three dashes ---
    hr: dim_color_wrapper,

    listBullet: cyan_color_wrapper,
    bold: get_color_wrapper(1),
    italic: get_color_wrapper(3), // 3 = italic
    strikethrough: get_color_wrapper(9), // strikethrough = 9
    underline: get_color_wrapper(4), // underline = 4
};

export {
    mdTheme,
    editorTheme,
    editorSelectListTheme,
    dim_color_wrapper,
    cyan_color_wrapper,
    red_color_wrapper,
    magneta_color_wrapper,
};

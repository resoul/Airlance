import Subtitles

extension SubtitleStrings {
    static func app(_ strings: AppStrings) -> SubtitleStrings {
        SubtitleStrings(
            title: strings.subtitlesTitle,
            show: strings.subtitlesShow,
            language: strings.subtitlesLanguage,
            style: strings.subtitlesStyle,
            styles: (strings.subtitlesStyleShadow, strings.subtitlesStylePlate, strings.subtitlesStylePop),
            empty: strings.subtitlesEmpty,
            hint: strings.subtitlesHint,
            add: strings.subtitlesAdd,
            edit: strings.subtitlesEdit,
            save: strings.subtitlesSave,
            cancel: strings.chatCancel
        )
    }
}

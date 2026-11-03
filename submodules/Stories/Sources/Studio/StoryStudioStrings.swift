import UIKit

public struct StoryStudioStrings: Sendable {
    public let cancel: String
    public let text: String
    public let draw: String
    public let undo: String
    public let done: String
    public let publish: String
    public let audience: String
    public let audiences: [StoryAudience: String]
    public let subtitles: String
    public let labels: [StoryLabel: String]

    public init(
        cancel: String,
        text: String,
        draw: String,
        undo: String,
        done: String,
        publish: String,
        audience: String,
        audiences: [StoryAudience: String],
        subtitles: String,
        labels: [StoryLabel: String]
    ) {
        self.cancel = cancel
        self.text = text
        self.draw = draw
        self.undo = undo
        self.done = done
        self.publish = publish
        self.audience = audience
        self.audiences = audiences
        self.subtitles = subtitles
        self.labels = labels
    }

    public func label(_ key: StoryLabel) -> String {
        labels[key] ?? key.rawValue
    }
}

public enum StoryLabel: String, CaseIterable, Sendable {
    case sticker
    case adjust
    case cutout
    case cutoutFailed
    case trim
    case cover
    case reset
    case penBrush
    case markerBrush
    case neonBrush
    case arrowBrush
    case eraser
    case brightness
    case contrast
    case saturation
    case warmth
    case vignette
    case filterOriginal
    case filterVivid
    case filterWarm
    case filterCool
    case filterFade
    case filterMono
    case filterNoir
    case filterChrome
    case drafts
    case saveDraft
    case discardStory
    case lifetime
    case hoursShort
    case pinToProfile
    case protectContent
    case captionPlaceholder
    case exceptPeople
    case choosePeople
    case nobody
    case searchPeople
    case editStory
    case deleteStory
    case repostStory
    case cancelMenu
    case collage
    case collageSlides
    case sound
    case soundAddTrack
    case soundOriginal
    case soundTrack
    case soundVoice
    case soundRecord
    case soundRecording
    case widgetMention
    case widgetLocation
    case widgetLink
    case widgetReaction
    case widgetPoll
    case widgetQuestion
    case widgetAddYours
    case widgetReactionHint
    case mentionPlaceholder
    case locationPlaceholder
    case linkPlaceholder
    case linkTitlePlaceholder
    case pollQuestionPlaceholder
    case pollOptionPlaceholder
    case questionDefault
    case questionHint
    case addYoursPlaceholder
    case openProfile
    case openMap
    case openLink
    case answerSend
    case answerSent
    case addYoursAction
}

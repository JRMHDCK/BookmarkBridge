#!/usr/bin/env python3
"""Generate the offline BookmarkBridge user guide bundled with the app."""

from pathlib import Path
import json
import shutil

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.platypus import (
    Flowable,
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
CATALOG = (
    ROOT
    / "BookmarkBridge"
    / "Documentation"
    / "Resources"
    / "Localizable.xcstrings"
)
LANGUAGES = ("en", "fr", "es", "de", "it", "pt", "nl", "pl")
GUIDE_IMAGES = ROOT / "Documentation" / "UserGuide" / "Images"
TRANSLATIONS: dict[str, str] = {}


def load_translations(language: str) -> dict[str, str]:
    catalog = json.loads(CATALOG.read_text())
    return {
        key: entry["localizations"][language]["stringUnit"]["value"]
        for key, entry in catalog["strings"].items()
    }


def tr(key: str) -> str:
    return TRANSLATIONS[key]


def destinations(language: str) -> tuple[Path, Path, Path]:
    filename = f"BookmarkBridge-User-Guide-{language}.pdf"
    return (
        ROOT / "output" / "pdf" / filename,
        ROOT / "BookmarkBridge" / "Documentation" / "Resources" / filename,
        ROOT / "Distribution" / "Website" / "downloads" / filename,
    )

NAVY = colors.HexColor("#172033")
BLUE = colors.HexColor("#2879E0")
PALE_BLUE = colors.HexColor("#EAF3FF")
PALE_GRAY = colors.HexColor("#F4F6F8")
GRAY = colors.HexColor("#667085")
RULE = colors.HexColor("#D8DEE8")
WHITE = colors.white


def register_fonts() -> tuple[str, str, str]:
    supplemental = Path("/System/Library/Fonts/Supplemental")
    regular = supplemental / "Arial.ttf"
    bold = supplemental / "Arial Bold.ttf"
    medium = supplemental / "Arial Bold.ttf"
    if regular.exists() and bold.exists() and medium.exists():
        pdfmetrics.registerFont(TTFont("SF", str(regular)))
        pdfmetrics.registerFont(TTFont("SF-Bold", str(bold)))
        pdfmetrics.registerFont(TTFont("SF-Medium", str(medium)))
        return "SF", "SF-Bold", "SF-Medium"
    return "Helvetica", "Helvetica-Bold", "Helvetica-Bold"


FONT, FONT_BOLD, FONT_MEDIUM = register_fonts()


class BookmarkMark(Flowable):
    def __init__(self, size: float = 31 * mm):
        super().__init__()
        self.width = size
        self.height = size

    def draw(self) -> None:
        canvas = self.canv
        canvas.setFillColor(BLUE)
        canvas.roundRect(0, 0, self.width, self.height, 8 * mm, fill=1, stroke=0)
        canvas.setFillColor(WHITE)
        left = self.width * 0.33
        right = self.width * 0.67
        bottom = self.height * 0.23
        top = self.height * 0.75
        middle = self.width * 0.50
        path = canvas.beginPath()
        path.moveTo(left, top)
        path.lineTo(right, top)
        path.lineTo(right, bottom)
        path.lineTo(middle, bottom + self.height * 0.13)
        path.lineTo(left, bottom)
        path.close()
        canvas.drawPath(path, fill=1, stroke=0)


styles = getSampleStyleSheet()
styles.add(
    ParagraphStyle(
        "CoverTitle",
        fontName=FONT_BOLD,
        fontSize=31,
        leading=36,
        textColor=NAVY,
        alignment=TA_CENTER,
        spaceAfter=5 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "CoverSubtitle",
        fontName=FONT,
        fontSize=14,
        leading=20,
        textColor=GRAY,
        alignment=TA_CENTER,
    )
)
styles.add(
    ParagraphStyle(
        "SectionTitle",
        fontName=FONT_BOLD,
        fontSize=23,
        leading=29,
        textColor=NAVY,
        spaceAfter=5 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "Heading",
        fontName=FONT_MEDIUM,
        fontSize=14,
        leading=19,
        textColor=NAVY,
        spaceBefore=4 * mm,
        spaceAfter=2 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "Body",
        fontName=FONT,
        fontSize=10.5,
        leading=15.5,
        textColor=NAVY,
        spaceAfter=3 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "Small",
        fontName=FONT,
        fontSize=9,
        leading=13,
        textColor=GRAY,
    )
)
styles.add(
    ParagraphStyle(
        "CalloutTitle",
        fontName=FONT_MEDIUM,
        fontSize=10.5,
        leading=14,
        textColor=NAVY,
        spaceAfter=1.5 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "CalloutBody",
        fontName=FONT,
        fontSize=9.5,
        leading=14,
        textColor=NAVY,
    )
)
styles.add(
    ParagraphStyle(
        "TOC",
        fontName=FONT_MEDIUM,
        fontSize=12,
        leading=18,
        textColor=NAVY,
        leftIndent=3 * mm,
    )
)


def paragraph(text: str) -> Paragraph:
    return Paragraph(text, styles["Body"])


def heading(text: str) -> Paragraph:
    return Paragraph(text, styles["Heading"])


def guide_image(filename: str, max_width: float, max_height: float) -> Image:
    image = Image(str(GUIDE_IMAGES / filename))
    scale = min(max_width / image.imageWidth, max_height / image.imageHeight)
    image.drawWidth = image.imageWidth * scale
    image.drawHeight = image.imageHeight * scale
    image.hAlign = "CENTER"
    return image


def bullets(items: list[str], numbered: bool = False) -> ListFlowable:
    options = {
        "bulletType": "1" if numbered else "bullet",
        "leftIndent": 7 * mm,
        "bulletFontName": FONT_MEDIUM,
        "bulletFontSize": 9,
        "bulletColor": BLUE,
        "spaceAfter": 3 * mm,
    }
    if numbered:
        options["start"] = "1"
    else:
        options["bulletChar"] = "•"
    return ListFlowable(
        [
            ListItem(Paragraph(item, styles["Body"]), leftIndent=4 * mm)
            for item in items
        ],
        **options,
    )


def callout(title: str, body: str, blue: bool = True) -> Table:
    background = PALE_BLUE if blue else PALE_GRAY
    data = [[
        Paragraph(title, styles["CalloutTitle"]),
        Paragraph(body, styles["CalloutBody"]),
    ]]
    table = Table(data, colWidths=[39 * mm, 111 * mm], hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), background),
                ("BOX", (0, 0), (-1, -1), 0.5, RULE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 3.5 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5 * mm),
            ]
        )
    )
    return table


def section(title: str, intro: str, content: list) -> list:
    return [
        Paragraph(title, styles["SectionTitle"]),
        paragraph(intro),
        Spacer(1, 1 * mm),
        *content,
    ]


def draw_page(canvas, document) -> None:
    canvas.saveState()
    width, height = A4
    if document.page > 1:
        canvas.setStrokeColor(RULE)
        canvas.setLineWidth(0.5)
        canvas.line(24 * mm, height - 17 * mm, width - 24 * mm, height - 17 * mm)
        canvas.setFont(FONT_MEDIUM, 8.5)
        canvas.setFillColor(NAVY)
        canvas.drawString(24 * mm, height - 13 * mm, "BOOKMARKBRIDGE")
        canvas.setFont(FONT, 8.5)
        canvas.setFillColor(GRAY)
        canvas.drawRightString(
            width - 24 * mm,
            height - 13 * mm,
            tr('manual.userGuide091Beta'),
        )
        canvas.drawString(24 * mm, 14 * mm, tr('manual.localDocumentation'))
        canvas.drawRightString(width - 24 * mm, 14 * mm, str(document.page))
    canvas.restoreState()


def build_story() -> list:
    story = [
        Spacer(1, 34 * mm),
        Table([[BookmarkMark()]], colWidths=[31 * mm], hAlign="CENTER"),
        Spacer(1, 11 * mm),
        Paragraph("BookmarkBridge", styles["CoverTitle"]),
        Paragraph(tr('manual.userGuide'), styles["CoverTitle"]),
        Paragraph(
            tr('manual.syncSafariAndGoogleChromeWithVisibility'),
            styles["CoverSubtitle"],
        ),
        Spacer(1, 20 * mm),
        Table(
            [[
                Paragraph(tr('manual.version091Beta'), styles["Small"]),
                Paragraph(tr('manual.systemRequirementsMacOS265OrLater'), styles["Small"]),
                Paragraph(tr('manual.engineBSEV10'), styles["Small"]),
            ]],
            colWidths=[48 * mm, 62 * mm, 40 * mm],
            style=TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), PALE_GRAY),
                    ("BOX", (0, 0), (-1, -1), 0.5, RULE),
                    ("INNERGRID", (0, 0), (-1, -1), 0.5, RULE),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                    ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
                ]
            ),
        ),
        Spacer(1, 9 * mm),
        Paragraph(
            tr('manual.allProcessingHappensLocallyOnYourMac'),
            styles["CoverSubtitle"],
        ),
        PageBreak(),
        Paragraph(tr('manual.summary'), styles["SectionTitle"]),
    ]
    toc = [
        tr('manual.1Presentation'),
        tr('manual.2Installation'),
        tr('manual.3Setup'),
        tr('manual.4Synchronization'),
        tr('manual.5PermissionsAndPrivacy'),
        tr('manual.6FrequentlyAskedQuestions'),
        tr('manual.7Troubleshooting'),
        tr('manual.8BestPractices'),
        tr('manual.9Appendix'),
    ]
    for item in toc:
        story.append(
            Table(
                [[Paragraph(item, styles["TOC"])]],
                colWidths=[150 * mm],
                style=TableStyle(
                    [
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
                        ("TOPPADDING", (0, 0), (-1, -1), 3 * mm),
                        ("LINEBELOW", (0, 0), (-1, -1), 0.35, RULE),
                    ]
                ),
            )
        )

    story.extend(
        [
            PageBreak(),
            *section(
                tr('manual.1Presentation'),
                tr('manual.bookmarkbridgeIsANativeMacOSAppThat'),
                [
                    heading(tr('manual.whatTheBetaDoes')),
                    bullets(
                        [
                            tr('manual.readsSafariLibrariesAndChromeProfilesThat'),
                            tr('manual.allowsYouToSelectProfilesFoldersAnd'),
                            tr('manual.presentsTheDifferencesBeforeAnyModification'),
                            tr('manual.createsARestorableBackupOfSafariOr'),
                        ]
                    ),
                    heading(tr('manual.aCautiousApproach')),
                    paragraph(
                        tr('manual.theDashboardClearlyDistinguishesBetweenReadingComparison')
                    ),
                    callout(
                        tr('manual.toRemember'),
                        tr('manual.bothDirectionsUseTheSameSecurePipeline'),
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.2Installation'),
                tr('manual.bookmarkbridge091BetaRequiresMacOS'),
                [
                    heading(tr('manual.installTheApp')),
                    bullets(
                        [
                            tr('manual.downloadAndOpenBookmarkBridge091'),
                            tr('manual.dragBookmarkBridgeAppToTheApplicationsShortcut'),
                            tr('manual.openBookmarkBridgeFromTheApplicationsFolder'),
                            tr('manual.followTheWelcomeGuideWhenFirstLaunching'),
                            tr('manual.grantSafariAndChromeAccessSeparatelyWhen'),
                        ],
                        numbered=True,
                    ),
                    heading(tr('manual.supportedBrowsers')),
                    paragraph(
                        tr('manual.thisVersionSupportsSafariAndGoogleChrome')
                    ),
                    callout(
                        tr('manual.noLoginRequired'),
                        tr('manual.bookmarkbridgeDoesNotDependOnAnyOnline'),
                        blue=False,
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.firstOpeningStep1Of3'),
                tr('manual.theBetaIsNotYetNotarizedBy'),
                [
                    heading(tr('manual.tryOpening')),
                    paragraph(
                        tr('manual.afterPlacingBookmarkBridgeInApplicationsOpenThe')
                    ),
                    Spacer(1, 3 * mm),
                    guide_image("gatekeeper-step-1.png", 92 * mm, 92 * mm),
                    Spacer(1, 5 * mm),
                    callout(
                        tr('manual.expectedMessage'),
                        tr('manual.thisMessageAppearsBecauseThisBetaHas'),
                        blue=False,
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.firstOpeningStep2Of3'),
                tr('manual.openSystemSettingsThenPrivacySecurityScroll'),
                [
                    heading(tr('manual.authorizeThisApp')),
                    paragraph(
                        tr('manual.nextToTheMessageBookmarkBridgeHasBeen')
                    ),
                    Spacer(1, 3 * mm),
                    guide_image("gatekeeper-step-2.png", 150 * mm, 126 * mm),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.firstOpeningStep3Of3'),
                tr('manual.macosAsksForAFinalConfirmationBefore'),
                [
                    heading(tr('manual.confirmOpening')),
                    paragraph(
                        tr('manual.clickOpenAnywayMacOSMayAskFor')
                    ),
                    Spacer(1, 3 * mm),
                    guide_image("gatekeeper-step-3.png", 102 * mm, 112 * mm),
                    Spacer(1, 5 * mm),
                    callout(
                        tr('manual.protectionsRetained'),
                        tr('manual.thisProcedureOnlyAllowsBookmarkBridgeItDoes'),
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.3Setup'),
                tr('manual.theSetupLinksBookmarkBridgeToChosenLibraries'),
                [
                    heading(tr('manual.safari')),
                    bullets(
                        [
                            tr('manual.inTheDashboardChooseAllowForSafari'),
                            tr('manual.selectTheBookmarksPlistFileOfferedIn'),
                            tr('manual.verifyThatTheAllowedStatusAppearsBefore'),
                        ],
                        numbered=True,
                    ),
                    heading(tr('manual.googleChrome')),
                    bullets(
                        [
                            tr('manual.chooseAllowForChrome'),
                            tr('manual.selectTheRequestedChromeFolderThenThe'),
                            tr('manual.checkTheNumberOfFavoritesDetectedIn'),
                        ],
                        numbered=True,
                    ),
                    heading(tr('manual.multipleChromeProfiles')),
                    paragraph(
                        tr('manual.eachProfileMaintainsItsOwnLibrarySynchronization')
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.4Synchronization'),
                tr('manual.synchronizationFollowsTheSameSecurePathIn'),
                [
                    heading(tr('manual.recommendedProcedure')),
                    bullets(
                        [
                            tr('manual.reloadTheSourcesToReadTheirCurrent'),
                            tr('manual.chooseTheDirectionSafariToChromeOr'),
                            tr('manual.checkTheProfilesFoldersAndFavoritesTo'),
                            tr('manual.reviewTheFullOverviewOfTheOperations'),
                            tr('manual.closeSafariAndChrome'),
                            tr('manual.confirmSynchronizationIsApplied'),
                            tr('manual.checkTheResultAndThenReopenThe'),
                        ],
                        numbered=True,
                    ),
                    callout(
                        tr('manual.explicitSelection'),
                        tr('manual.anUncheckedItemIsIgnoredEntirelyBy'),
                    ),
                    heading(tr('manual.supportedOperations')),
                    paragraph(
                        tr('manual.dependingOnTheDirectionAndSelectionThe')
                    ),
                    heading(tr('manual.afterApplication')),
                    paragraph(
                        tr('manual.bookmarkbridgeAutomaticallyReloadsTheDashboardAndPreview')
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.5PermissionsAndPrivacy'),
                tr('manual.theMacOSSandboxPreventsAnAppFrom'),
                [
                    heading(tr('manual.whyMacOSAsksForPermission')),
                    paragraph(
                        tr('manual.thePermissionIsSavedByMacOSIn')
                    ),
                    heading(tr('manual.ifAnAuthorizationExpires')),
                    paragraph(
                        tr('manual.chooseAllowAgainFromTheDashboardThen')
                    ),
                    heading(tr('manual.localData')),
                    bullets(
                        [
                            tr('manual.noFavoritesAreTransmittedOverTheNetwork'),
                            tr('manual.chromeAccountBookmarksRemainsReadOnly'),
                            tr('manual.aSafariOrChromeBackupPrecedesAny'),
                            tr('manual.safariAndChromeMustBeClosedWhile'),
                        ]
                    ),
                    callout(
                        tr('manual.explicitControl'),
                        tr('manual.anAnalysisAlwaysHasNoEffectOn'),
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.6FrequentlyAskedQuestions'),
                tr('manual.theAnswersBelowCoverTheMostCommon'),
                [
                    KeepTogether([
                        heading(tr('manual.whyDoesChromeAppearBlank')),
                        paragraph(
                            tr('manual.checkTheSelectedProfileAndItsAuthorization')
                        ),
                    ]),
                    KeepTogether([
                        heading(tr('manual.whatHappensIfIUncheckAFavorite')),
                        paragraph(
                            tr('manual.itIsExcludedFromComparisonPreviewAnd')
                        ),
                    ]),
                    KeepTogether([
                        heading(tr('manual.whyDoesAFolderAppearDuplicated')),
                        paragraph(
                            tr('manual.foldersWithTheSameNameCanBelong')
                        ),
                    ]),
                    KeepTogether([
                        heading(tr('manual.canISyncMultipleChromeProfiles')),
                        paragraph(
                            tr('manual.yesEachSyncUsesASpecificLocal')
                        ),
                    ]),
                    KeepTogether([
                        heading(tr('manual.whatHappensIfIDeleteAFavorite')),
                        paragraph(
                            tr('manual.thePreviewMaySuggestRemovingItIn')
                        ),
                    ]),
                    KeepTogether([
                        heading(tr('manual.howToRestoreABackup')),
                        paragraph(
                            tr('manual.closeSafariAndChromeOpenTheLatest')
                        ),
                    ]),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.7Troubleshooting'),
                tr('manual.messagesFromBookmarkBridgeIndicateTheProbableCause'),
                [
                    heading(tr('manual.unableToAccessSafari')),
                    paragraph(
                        tr('manual.thePermissionHasProbablyExpiredOrThe')
                    ),
                    heading(tr('manual.safariAndChromeMustBeClosed')),
                    paragraph(
                        tr('manual.quitSafariAndChromeWithCommandQ')
                    ),
                    heading(tr('manual.twoChromeStoragesAreDetected')),
                    paragraph(
                        tr('manual.theProfileContainsLocalDataAndAccount')
                    ),
                    heading(tr('manual.previewIsNotDisplayed')),
                    paragraph(
                        tr('manual.reloadSafariAndChromeFromTheDashboard')
                    ),
                    callout(
                        tr('manual.yourDataRemainsProtected'),
                        tr('manual.ifThisFailsBookmarkBridgeAbortsTheOperation'),
                        blue=False,
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.8BestPractices'),
                tr('manual.aFewSimpleHabitsMakeEverySync'),
                [
                    bullets(
                        [
                            tr('manual.alwaysReviewThePreviewBeforeConfirming'),
                            tr('manual.closeSafariAndChromeBeforeSyncingOr'),
                            tr('manual.doNotMoveBrowserFilesDuringAn'),
                            tr('manual.startWithAChromeProfileWhoseContent'),
                            tr('manual.afterASyncCheckAFewBookmarks'),
                            tr('manual.keepTheAppUpdatedAndSeeWhat'),
                        ]
                    ),
                    heading(tr('manual.beforeAnImportantOperation')),
                    paragraph(
                        tr('manual.rechargeBothSourcesCheckTheirMetersAnd')
                    ),
                    callout(
                        tr('manual.essentialPrinciple'),
                        tr('manual.theSafetyOfFavoritesTakesPrecedenceOver'),
                    ),
                ],
            ),
            PageBreak(),
            *section(
                tr('manual.9Appendix'),
                tr('manual.technicalReferencesAndVocabularyUsefulForUnderstanding'),
                [
                    heading(tr('manual.glossary')),
                    bullets(
                        [
                            tr('manual.previewReadableSimulationOfChangesWithoutWriting'),
                            tr('manual.librarySetOfFavoritesAndFoldersIn'),
                            tr('manual.chromeProfileChromeUserAreaWithIts'),
                            tr('manual.backupRestorableCopyOfTheTargetLibrary'),
                            tr('manual.sensSafariToChromeOrChromeTo'),
                            tr('manual.selectionExplicitScopeOfElementsIncludedIn'),
                        ]
                    ),
                    heading(tr('manual.betaCompatibility')),
                    bullets(
                        [
                            tr('manual.bookmarkbridge091BetaBuild1'),
                            tr('manual.bseV10'),
                            tr('manual.macos265OrLater'),
                            tr('manual.safariAndGoogleChrome'),
                            tr('manual.universalBinaryArm64AndX8664'),
                        ]
                    ),
                    heading(tr('manual.confirmedLimits')),
                    paragraph(
                        tr('manual.onlySafariAndGoogleChromeAreSupported')
                    ),
                    callout(
                        tr('manual.builtInHelp'),
                        tr('manual.forInformationAdaptedToTheScreenDisplayed'),
                        blue=False,
                    ),
                ],
            ),
        ]
    )
    return story


def generate(language: str) -> None:
    global TRANSLATIONS
    TRANSLATIONS = load_translations(language)
    output, bundled, website = destinations(language)
    output.parent.mkdir(parents=True, exist_ok=True)
    bundled.parent.mkdir(parents=True, exist_ok=True)
    website.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(output),
        pagesize=A4,
        rightMargin=24 * mm,
        leftMargin=24 * mm,
        topMargin=24 * mm,
        bottomMargin=22 * mm,
        title=tr('manual.bookmarkbridgeUserGuide'),
        author=tr('manual.jeromeHudecek'),
        subject=tr('manual.bookmarkbridge091BetaOfflineUser'),
        creator=tr('manual.bookmarkbridgeDocumentation'),
    )
    document.build(build_story(), onFirstPage=draw_page, onLaterPages=draw_page)
    shutil.copyfile(output, bundled)
    shutil.copyfile(output, website)
    if language == "en":
        shutil.copyfile(
            output,
            ROOT / "output" / "pdf" / "BookmarkBridge-User-Guide.pdf",
        )
        shutil.copyfile(
            output,
            ROOT / "BookmarkBridge" / "Documentation" / "Resources"
            / "BookmarkBridge-User-Guide.pdf",
        )
        shutil.copyfile(
            output,
            ROOT / "Distribution" / "Website" / "downloads"
            / "BookmarkBridge-User-Guide.pdf",
        )
    print(f"Generated {language}: {output}")


if __name__ == "__main__":
    for language in LANGUAGES:
        generate(language)

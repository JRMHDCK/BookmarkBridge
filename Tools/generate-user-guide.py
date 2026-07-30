#!/usr/bin/env python3
"""Generate the offline BookmarkBridge user guide bundled with the app."""

from pathlib import Path
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
OUTPUT = ROOT / "output" / "pdf" / "BookmarkBridge-User-Guide.pdf"
BUNDLED = (
    ROOT
    / "BookmarkBridge"
    / "Documentation"
    / "Resources"
    / "BookmarkBridge-User-Guide.pdf"
)

NAVY = colors.HexColor("#172033")
BLUE = colors.HexColor("#2879E0")
PALE_BLUE = colors.HexColor("#EAF3FF")
PALE_GRAY = colors.HexColor("#F4F6F8")
GRAY = colors.HexColor("#667085")
RULE = colors.HexColor("#D8DEE8")
WHITE = colors.white


def register_fonts() -> tuple[str, str, str]:
    regular = Path("/System/Library/Fonts/SFNS.ttf")
    bold = Path("/System/Library/Fonts/SFNSDisplay-Bold.otf")
    medium = Path("/System/Library/Fonts/SFNSDisplay-Medium.otf")
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
            "Guide de l’utilisateur · 0.9.0-beta1",
        )
        canvas.drawString(24 * mm, 14 * mm, "Documentation locale")
        canvas.drawRightString(width - 24 * mm, 14 * mm, str(document.page))
    canvas.restoreState()


def build_story() -> list:
    story = [
        Spacer(1, 34 * mm),
        Table([[BookmarkMark()]], colWidths=[31 * mm], hAlign="CENTER"),
        Spacer(1, 11 * mm),
        Paragraph("BookmarkBridge", styles["CoverTitle"]),
        Paragraph("Guide de l’utilisateur", styles["CoverTitle"]),
        Paragraph(
            "Synchroniser Safari et Google Chrome<br/>avec visibilité, contrôle et sauvegarde.",
            styles["CoverSubtitle"],
        ),
        Spacer(1, 20 * mm),
        Table(
            [[
                Paragraph("<b>Version</b><br/>0.9.0-beta1", styles["Small"]),
                Paragraph("<b>Configuration requise</b><br/>macOS 26.5 ou ultérieur", styles["Small"]),
                Paragraph("<b>Moteur</b><br/>BSE v1.0", styles["Small"]),
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
            "Tout le traitement s’effectue localement sur votre Mac. "
            "Ce guide est disponible sans connexion Internet.",
            styles["CoverSubtitle"],
        ),
        PageBreak(),
        Paragraph("Sommaire", styles["SectionTitle"]),
    ]
    toc = [
        "1. Présentation",
        "2. Installation",
        "3. Configuration",
        "4. Synchronisation",
        "5. Autorisations et confidentialité",
        "6. Questions fréquentes",
        "7. Dépannage",
        "8. Bonnes pratiques",
        "9. Annexe",
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
                "1. Présentation",
                "BookmarkBridge est une application macOS native qui compare les favoris "
                "de Safari et de Google Chrome avant d’appliquer des ajouts contrôlés.",
                [
                    heading("Ce que fait la version bêta"),
                    bullets(
                        [
                            "Lit les bibliothèques Safari et les profils Chrome que vous autorisez.",
                            "Présente les différences avant toute modification.",
                            "Ajoute à Chrome les favoris Safari manquants, sans supprimer les favoris existants.",
                            "Crée une sauvegarde restaurable avant chaque écriture.",
                        ]
                    ),
                    heading("Une approche prudente"),
                    paragraph(
                        "Le tableau de bord distingue clairement la lecture, la comparaison et "
                        "l’application. Une analyse ne modifie jamais vos données. La synchronisation "
                        "nécessite toujours une action explicite après l’aperçu."
                    ),
                    callout(
                        "À retenir",
                        "Safari reste en lecture seule dans cette version. Les écritures concernent "
                        "uniquement le fichier Bookmarks local du profil Chrome sélectionné.",
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "2. Installation",
                "BookmarkBridge 0.9.0-beta1 nécessite macOS 26.5 ou une version ultérieure "
                "et fonctionne sur les Mac Apple Silicon et Intel 64 bits.",
                [
                    heading("Installer l’application"),
                    bullets(
                        [
                            "Placez BookmarkBridge dans le dossier Applications.",
                            "Ouvrez l’application depuis le Finder.",
                            "Suivez le guide de bienvenue lors du premier lancement.",
                            "Accordez séparément les accès Safari et Chrome lorsque macOS les demande.",
                        ],
                        numbered=True,
                    ),
                    heading("Navigateurs pris en charge"),
                    paragraph(
                        "Cette version prend en charge Safari et Google Chrome. Firefox, Edge "
                        "et les autres navigateurs ne sont pas encore disponibles."
                    ),
                    callout(
                        "Aucune connexion requise",
                        "BookmarkBridge ne dépend d’aucun compte en ligne et n’envoie pas vos "
                        "favoris vers un service distant.",
                        blue=False,
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "3. Configuration",
                "La configuration relie BookmarkBridge aux bibliothèques choisies grâce au "
                "sélecteur de fichiers sécurisé de macOS.",
                [
                    heading("Safari"),
                    bullets(
                        [
                            "Dans le tableau de bord, choisissez Autoriser pour Safari.",
                            "Sélectionnez le fichier Bookmarks.plist proposé dans le dossier Safari.",
                            "Vérifiez que l’état Autorisé apparaît avant de continuer.",
                        ],
                        numbered=True,
                    ),
                    heading("Google Chrome"),
                    bullets(
                        [
                            "Choisissez Autoriser pour Chrome.",
                            "Sélectionnez le dossier Chrome demandé, puis le profil à utiliser.",
                            "Vérifiez le nombre de favoris détectés dans le tableau de bord.",
                        ],
                        numbered=True,
                    ),
                    heading("Plusieurs profils Chrome"),
                    paragraph(
                        "Chaque profil conserve sa propre bibliothèque. Sélectionnez le profil "
                        "correspondant à votre usage courant. Un profil contenant simultanément "
                        "un stockage local et un stockage de compte actifs reste en lecture seule."
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "4. Synchronisation",
                "La synchronisation suit un parcours en deux temps : apercevoir, puis confirmer.",
                [
                    heading("Procédure recommandée"),
                    bullets(
                        [
                            "Rechargez les sources pour lire leur état actuel.",
                            "Ouvrez Synchronisation et examinez le résumé des ajouts.",
                            "Développez les détails pour contrôler les favoris concernés.",
                            "Fermez complètement Google Chrome.",
                            "Confirmez l’application de la synchronisation.",
                            "Vérifiez le résultat, puis rouvrez Chrome.",
                        ],
                        numbered=True,
                    ),
                    callout(
                        "Synchronisation additive",
                        "Cette bêta ajoute à Chrome les favoris Safari absents. Elle ne supprime "
                        "ni ne remplace les favoris déjà présents dans Chrome.",
                    ),
                    heading("Après l’application"),
                    paragraph(
                        "BookmarkBridge recharge automatiquement le tableau de bord et l’aperçu. "
                        "Une seconde exécution ne doit pas recréer les mêmes favoris."
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "5. Autorisations et confidentialité",
                "Le sandbox macOS empêche une application d’accéder librement à vos fichiers. "
                "Vous choisissez donc explicitement chaque bibliothèque.",
                [
                    heading("Pourquoi macOS demande une autorisation"),
                    paragraph(
                        "L’autorisation est enregistrée par macOS sous une forme sécurisée. "
                        "BookmarkBridge ne parcourt pas vos autres documents et ne demande pas "
                        "de désactiver les protections du système."
                    ),
                    heading("Si une autorisation expire"),
                    paragraph(
                        "Choisissez de nouveau Autoriser dans le tableau de bord, puis sélectionnez "
                        "la même bibliothèque. Cette opération ne modifie aucun favori."
                    ),
                    heading("Données locales"),
                    bullets(
                        [
                            "Aucun favori n’est transmis sur le réseau.",
                            "Safari et AccountBookmarks restent en lecture seule.",
                            "Une sauvegarde précède toute modification de Chrome.",
                            "Chrome doit être fermé pendant l’écriture ou la restauration.",
                        ]
                    ),
                    callout(
                        "Contrôle explicite",
                        "Une analyse est toujours sans effet sur les données. Seul le bouton "
                        "de confirmation de l’aperçu autorise une écriture.",
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "6. Questions fréquentes",
                "Les réponses ci-dessous couvrent les situations les plus courantes.",
                [
                    KeepTogether([
                        heading("Pourquoi Chrome apparaît-il vide ?"),
                        paragraph(
                            "Vérifiez le profil sélectionné et son autorisation. Un profil différent "
                            "peut contenir une bibliothèque distincte."
                        ),
                    ]),
                    KeepTogether([
                        heading("Que se passe-t-il si je supprime un favori ?"),
                        paragraph(
                            "La bêta n’applique pas les suppressions. Elle ajoute uniquement les "
                            "favoris Safari manquants au stockage local Chrome."
                        ),
                    ]),
                    KeepTogether([
                        heading("Pourquoi un dossier semble-t-il dupliqué ?"),
                        paragraph(
                            "Des dossiers portant le même nom peuvent appartenir à des chemins "
                            "différents. Consultez leur hiérarchie dans l’explorateur."
                        ),
                    ]),
                    KeepTogether([
                        heading("Puis-je synchroniser plusieurs profils Chrome ?"),
                        paragraph(
                            "Vous pouvez autoriser et consulter plusieurs profils, mais chaque "
                            "synchronisation cible un seul stockage local clairement sélectionné."
                        ),
                    ]),
                    KeepTogether([
                        heading("Comment restaurer une sauvegarde ?"),
                        paragraph(
                            "Fermez Chrome, ouvrez le dernier résultat de synchronisation, choisissez "
                            "Restaurer et confirmez. Le tableau de bord est ensuite rechargé."
                        ),
                    ]),
                ],
            ),
            PageBreak(),
            *section(
                "7. Dépannage",
                "Les messages de BookmarkBridge indiquent la cause probable et l’action à effectuer.",
                [
                    heading("Impossible d’accéder à Safari"),
                    paragraph(
                        "L’autorisation a probablement expiré ou le fichier a été déplacé. "
                        "Choisissez Autoriser, puis sélectionnez à nouveau Bookmarks.plist."
                    ),
                    heading("Chrome doit être fermé"),
                    paragraph(
                        "Quittez Chrome avec Commande-Q. Vérifiez qu’aucune fenêtre ni processus "
                        "Chrome ne reste actif, puis réessayez."
                    ),
                    heading("Deux stockages Chrome sont détectés"),
                    paragraph(
                        "Le profil contient des données locales et des données de compte. "
                        "BookmarkBridge le conserve en lecture seule afin de ne pas choisir "
                        "arbitrairement une source."
                    ),
                    heading("La prévisualisation ne s’affiche pas"),
                    paragraph(
                        "Rechargez Safari et Chrome depuis le tableau de bord. Corrigez les "
                        "autorisations signalées, puis relancez la comparaison."
                    ),
                    callout(
                        "Vos données restent protégées",
                        "En cas d’échec, BookmarkBridge interrompt l’opération et conserve les "
                        "favoris existants. Ne modifiez pas manuellement les fichiers des navigateurs.",
                        blue=False,
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "8. Bonnes pratiques",
                "Quelques habitudes simples rendent chaque synchronisation plus facile à vérifier.",
                [
                    bullets(
                        [
                            "Examinez toujours l’aperçu avant de confirmer.",
                            "Fermez Chrome avant une synchronisation ou une restauration.",
                            "Ne déplacez pas les fichiers des navigateurs pendant une opération.",
                            "Commencez par un profil Chrome dont vous connaissez le contenu.",
                            "Après une synchronisation, vérifiez quelques favoris dans Chrome.",
                            "Conservez l’application à jour et consultez Nouveautés après une mise à niveau.",
                        ]
                    ),
                    heading("Avant une opération importante"),
                    paragraph(
                        "Rechargez les deux sources, contrôlez leurs compteurs et prenez le temps "
                        "de lire les éventuels encadrés d’avertissement. Si un profil est signalé "
                        "en lecture seule, ne tentez pas de contourner cette protection."
                    ),
                    callout(
                        "Principe essentiel",
                        "La sécurité des favoris prime sur la rapidité. En cas de doute, annulez "
                        "l’opération et consultez l’aide contextuelle de la vue.",
                    ),
                ],
            ),
            PageBreak(),
            *section(
                "9. Annexe",
                "Repères techniques et vocabulaire utiles pour comprendre l’application.",
                [
                    heading("Glossaire"),
                    bullets(
                        [
                            "<b>Aperçu</b> : simulation lisible des changements, sans écriture.",
                            "<b>Bibliothèque</b> : ensemble des favoris et dossiers d’un navigateur.",
                            "<b>Profil Chrome</b> : espace utilisateur Chrome possédant ses propres favoris.",
                            "<b>Sauvegarde</b> : copie restaurable créée avant une écriture.",
                            "<b>Synchronisation additive</b> : ajout des éléments absents sans suppression.",
                        ]
                    ),
                    heading("Compatibilité de la bêta"),
                    bullets(
                        [
                            "BookmarkBridge 0.9.0-beta1, build 1.",
                            "BSE v1.0.",
                            "macOS 26.5 ou ultérieur.",
                            "Safari et Google Chrome.",
                            "Binaire universel arm64 et x86_64.",
                        ]
                    ),
                    heading("Limites confirmées"),
                    paragraph(
                        "Les écritures vont uniquement de Safari vers le fichier Bookmarks local "
                        "de Chrome. La structure Safari n’est pas reconstruite : les nouveaux favoris "
                        "sont ajoutés à « Autres favoris ». Il n’existe pas de synchronisation cloud, "
                        "multi-machine, temps réel ou en arrière-plan."
                    ),
                    callout(
                        "Aide intégrée",
                        "Pour une information adaptée à l’écran affiché, utilisez le bouton d’aide "
                        "« ? ». Le centre d’aide est également disponible dans le menu Aide.",
                        blue=False,
                    ),
                ],
            ),
        ]
    )
    return story


def generate() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    BUNDLED.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=24 * mm,
        leftMargin=24 * mm,
        topMargin=24 * mm,
        bottomMargin=22 * mm,
        title="BookmarkBridge — Guide de l’utilisateur",
        author="Jérôme Hudecek",
        subject="Manuel utilisateur hors ligne de BookmarkBridge 0.9.0-beta1",
        creator="BookmarkBridge Documentation",
    )
    document.build(build_story(), onFirstPage=draw_page, onLaterPages=draw_page)
    shutil.copyfile(OUTPUT, BUNDLED)
    print(f"Generated {OUTPUT}")
    print(f"Bundled   {BUNDLED}")


if __name__ == "__main__":
    generate()

from datetime import date
import html
import json
import os
import re
import subprocess
import xml.etree.ElementTree as ET

_CWD = os.getcwd()
ROOT_DIR = _CWD if os.path.isdir(os.path.join(_CWD, "src")) else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT_DIR, "src")

BASE_URL = "https://quicknfc.link"
LANGS = ["en", "ar", "de", "es", "fr", "hi", "ja", "pt", "ru", "zh"]
OG_LOCALES = {
    "en": "en_US",
    "ar": "ar_AR",
    "de": "de_DE",
    "es": "es_ES",
    "fr": "fr_FR",
    "hi": "hi_IN",
    "ja": "ja_JP",
    "pt": "pt_PT",
    "ru": "ru_RU",
    "zh": "zh_CN",
}

TEXT_ELEMENT_MAP = [
    ("appTitle", "appTitle"),
    ("appSubtitle", "appSubtitle"),
    ("navGithubLabel", "navGithub"),
    ("navSupportLabel", "navSupport"),
    ("navApkLabel", "navApk"),
    ("apkDownloadLabel", "apkDownload"),
    ("tabLinkLabel", "tabLink"),
    ("tabSearchLabel", "tabSearch"),
    ("pasteBtnLabel", "pasteBtn"),
    ("btnText", "convertBtn"),
    ("resultLabelText", "resultLabelReview"),
    ("linkTypeSelectorLabel", "linkTypePrompt"),
    ("btnTypeReviewLabel", "linkTypeReview"),
    ("btnTypeLocationLabel", "linkTypeLocation"),
    ("nfcBtnLabel", "nfcBtn"),
    ("openBtnLabel", "openBtn"),
    ("copyBtnLabel", "copyBtn"),
    ("shareBtnLabel", "shareBtn"),
    ("qrBtnLabel", "qrBtn"),
    ("tagHowItWorks", "tagHowItWorks"),
    ("titleHowItWorks", "titleHowItWorks"),
    ("subHowItWorks", "subHowItWorks"),
    ("step1Title", "step1Title"),
    ("step1Desc", "step1Desc"),
    ("step2Title", "step2Title"),
    ("step2Desc", "step2Desc"),
    ("step3Title", "step3Title"),
    ("step3Desc", "step3Desc"),
    ("tagFeatures", "tagFeatures"),
    ("titleFeatures", "titleFeatures"),
    ("subFeatures", "subFeatures"),
    ("feat1Title", "feat1Title"),
    ("feat1Desc", "feat1Desc"),
    ("feat2Title", "feat2Title"),
    ("feat2Desc", "feat2Desc"),
    ("feat3Title", "feat3Title"),
    ("feat3Desc", "feat3Desc"),
    ("feat4Title", "feat4Title"),
    ("feat4Desc", "feat4Desc"),
    ("feat5Title", "feat5Title"),
    ("feat5Desc", "feat5Desc"),
    ("feat6Title", "feat6Title"),
    ("feat6Desc", "feat6Desc"),
    ("tagFaq", "tagFaq"),
    ("titleFaq", "titleFaq"),
    ("subFaq", "subFaq"),
    ("faq1Q", "faq1Q"),
    ("faq1A", "faq1A"),
    ("faq2Q", "faq2Q"),
    ("faq2A", "faq2A"),
    ("faq3Q", "faq3Q"),
    ("faq3A", "faq3A"),
    ("faq4Q", "faq4Q"),
    ("faq4A", "faq4A"),
    ("faq5Q", "faq5Q"),
    ("faq5A", "faq5A"),
    ("faq6Q", "faq6Q"),
    ("faq6A", "faq6A"),
    ("footerTagline", "footerTagline"),
    ("footerApkLink", "footerApk"),
    ("footerGithubLink", "footerGithub"),
    ("footerBackToTop", "footerBackToTop"),
    ("qrModalTitle", "qrModalTitle"),
    ("qrModalDesc", "qrModalDesc"),
    ("qrDownloadBtnLabel", "qrDownloadBtn"),
    ("qrCloseBtn", "qrCloseBtn"),
]

HTML_ELEMENT_MAP = [
    ("webPlatformNoticeText", "webPlatformNoticeText"),
    ("footerCopyright", "footerCopyright"),
]


def lang_url(lang: str) -> str:
    return f"{BASE_URL}/" if lang == "en" else f"{BASE_URL}/{lang}/"


def lang_output_path(lang: str) -> str:
    if lang == "en":
        return os.path.join(ROOT_DIR, "index.html")
    return os.path.join(ROOT_DIR, lang, "index.html")


def extract_i18n_data(i18n_js_path: str) -> tuple[dict, dict]:
    """Extract I18N and LANG_DISPLAY_NAMES from src/js/core/i18n.js using Node vm."""
    node_script = r"""
const fs = require('fs');
const vm = require('vm');
const code = fs.readFileSync(process.argv[1], 'utf8');
const noop = () => {};
const windowObj = {
  location: { pathname: '/' },
  matchMedia: () => ({ matches: false }),
  addEventListener: noop,
  requestAnimationFrame: noop,
};
const sandbox = {
  window: windowObj,
  document: {
    documentElement: { lang: 'en', dir: 'ltr' },
    body: { classList: { add: noop, remove: noop, toggle: noop, contains: () => false }, offsetWidth: 0 },
    title: '',
    getElementById: () => null,
    querySelector: () => null,
    querySelectorAll: () => [],
    addEventListener: noop,
  },
  localStorage: { getItem: () => null, setItem: noop },
  navigator: { userAgent: '' },
  setTimeout,
  clearTimeout,
  requestAnimationFrame: noop,
  cancelAnimationFrame: noop,
  console,
};
sandbox.self = sandbox.window;
sandbox.globalThis = sandbox.window;
vm.runInNewContext(code, sandbox);
process.stdout.write(JSON.stringify({
  I18N: sandbox.window.I18N,
  LANG_DISPLAY_NAMES: sandbox.window.LANG_DISPLAY_NAMES || {},
}));
"""
    res = subprocess.run(
        ["node", "-e", node_script, i18n_js_path],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    payload = json.loads(res.stdout)
    i18n = payload["I18N"]
    display_names = payload["LANG_DISPLAY_NAMES"]
    for lang in LANGS:
        if lang not in i18n:
            raise KeyError(f"Missing language '{lang}' in {i18n_js_path}")
    return i18n, display_names


def replace_element_content_by_id(doc: str, element_id: str, value: str, is_html: bool = False) -> str:
    open_pattern = re.compile(
        rf'<([a-zA-Z0-9]+)\b(?:"[^"]*"|\'[^\']*\'|[^>"\'])*\bid=(["\']){re.escape(element_id)}\2(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>'
    )
    matches = list(open_pattern.finditer(doc))
    if len(matches) != 1:
        raise ValueError(f"Expected 1 element with id='{element_id}', found {len(matches)}")

    match = matches[0]
    tag = match.group(1)
    open_end = match.end()

    tag_token_pattern = re.compile(rf'</?{re.escape(tag)}\b(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>')
    depth = 1
    close_start = None
    for token in tag_token_pattern.finditer(doc, open_end):
        raw = token.group(0)
        if raw.startswith("</"):
            depth -= 1
            if depth == 0:
                close_start = token.start()
                break
        elif not raw.endswith("/>"):
            depth += 1

    if close_start is None:
        raise ValueError(f"Unclosed <{tag} id='{element_id}'> tag")

    replacement = value if is_html else html.escape(value, quote=False)
    return doc[:open_end] + replacement + doc[close_start:]


def set_element_attr_by_id(doc: str, element_id: str, attr_name: str, value: str) -> str:
    open_pattern = re.compile(
        rf'<[a-zA-Z0-9]+\b(?:"[^"]*"|\'[^\']*\'|[^>"\'])*\bid=(["\']){re.escape(element_id)}\1(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>'
    )
    matches = list(open_pattern.finditer(doc))
    if len(matches) != 1:
        raise ValueError(f"Expected 1 element with id='{element_id}', found {len(matches)}")

    match = matches[0]
    tag_text = match.group(0)
    escaped = html.escape(value, quote=True)
    attr_pattern = re.compile(rf'(\b{re.escape(attr_name)}\s*=\s*)(?:"[^"]*"|\'[^\']*\')')
    if attr_pattern.search(tag_text):
        updated_tag = attr_pattern.sub(rf'\g<1>"{escaped}"', tag_text, count=1)
    else:
        updated_tag = tag_text[:-1] + f' {attr_name}="{escaped}">'

    return doc[:match.start()] + updated_tag + doc[match.end():]


def set_meta_content(doc: str, attr_name: str, attr_val: str, content: str) -> str:
    meta_pattern = re.compile(
        rf'<meta\b(?:"[^"]*"|\'[^\']*\'|[^>"\'])*\b{re.escape(attr_name)}=(["\']){re.escape(attr_val)}\1(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>'
    )
    matches = list(meta_pattern.finditer(doc))
    if len(matches) != 1:
        raise ValueError(f"Expected 1 <meta {attr_name}='{attr_val}'>, found {len(matches)}")

    match = matches[0]
    tag_text = match.group(0)
    escaped = html.escape(content, quote=True)
    updated_tag = re.sub(r'(\bcontent\s*=\s*)(?:"[^"]*"|\'[^\']*\')', rf'\g<1>"{escaped}"', tag_text, count=1)
    return doc[:match.start()] + updated_tag + doc[match.end():]


def build_hreflang_block() -> str:
    lines = ["    <!-- HREFLANG_START -->"]
    for lang in LANGS:
        lines.append(f'    <link rel="alternate" hreflang="{lang}" href="{lang_url(lang)}">')
    lines.append(f'    <link rel="alternate" hreflang="x-default" href="{BASE_URL}/">')
    lines.append("    <!-- HREFLANG_END -->")
    return "\n".join(lines)


def build_jsonld_block(lang: str, d: dict) -> str:
    page_url = lang_url(lang)
    faqs = []
    for i in range(1, 7):
        q = d[f"faq{i}Q"]
        a = d[f"faq{i}A"]
        faqs.append(
            {
                "@type": "Question",
                "name": q,
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": a,
                },
            }
        )

    data = [
        {
            "@context": "https://schema.org",
            "@type": "WebSite",
            "name": "Quick NFC",
            "alternateName": ["QuickNFC", "Google Review Link Generator", "Google Review QR Code Generator"],
            "url": page_url,
            "inLanguage": lang,
        },
        {
            "@context": "https://schema.org",
            "@type": "WebApplication",
            "name": "Quick NFC",
            "url": page_url,
            "inLanguage": lang,
            "image": f"{BASE_URL}/assets/icons/og-image.png",
            "description": d["metaDesc"],
            "applicationCategory": "BusinessApplication",
            "operatingSystem": "Web, Android",
            "offers": {
                "@type": "Offer",
                "price": "0",
                "priceCurrency": "USD",
            },
            "author": {
                "@type": "Person",
                "name": "Zaid Salameh",
                "url": "https://github.com/zaid-a-salameh",
            },
        },
        {
            "@context": "https://schema.org",
            "@type": "FAQPage",
            "inLanguage": lang,
            "mainEntity": faqs,
        },
    ]

    json_str = json.dumps(data, ensure_ascii=False, indent=2).replace("</", "<\\/")
    indented_json = "\n".join("    " + line for line in json_str.splitlines())
    return (
        "    <!-- JSONLD_START -->\n"
        '    <script type="application/ld+json" id="structuredDataJsonLd">\n'
        f"{indented_json}\n"
        "    </script>\n"
        "    <!-- JSONLD_END -->"
    )


def update_lang_selectors(doc: str, active_lang: str, display_names: dict) -> str:
    display_name = display_names.get(active_lang, "English")
    doc = replace_element_content_by_id(doc, "navLangLabel", display_name)
    doc = replace_element_content_by_id(doc, "topLangLabel", display_name)

    def toggle_dropdown_item(match: re.Match) -> str:
        tag = match.group(0)
        item_lang = match.group(3)

        def rewrite_class(c_match: re.Match) -> str:
            classes = [c for c in c_match.group(3).split() if c != "active"]
            if item_lang == active_lang:
                classes.append("active")
            return f'{c_match.group(1)}"{" ".join(classes)}"'

        return re.sub(r'(\bclass\s*=\s*)(["\'])([^"\']*)\2', rewrite_class, tag, count=1)

    doc = re.sub(
        r'<button\b(?:"[^"]*"|\'[^\']*\'|[^>"\'])*\bclass=(["\'])[^"\']*\blang-dropdown-item\b[^"\']*\1(?:"[^"]*"|\'[^\']*\'|[^>"\'])*\bdata-lang=(["\'])([a-z]{2})\2(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>',
        toggle_dropdown_item,
        doc,
    )

    def update_footer_nav(nav_match: re.Match) -> str:
        nav_block = nav_match.group(0)

        def update_footer_link(a_match: re.Match) -> str:
            tag = a_match.group(0)
            item_lang = a_match.group(2)
            # Remove any existing class or aria-current attributes and rebuild cleanly
            tag = re.sub(r'\s*\bclass\s*=\s*(?:"[^"]*"|\'[^\']*\')', "", tag)
            tag = re.sub(r'\s*\baria-current\s*=\s*(?:"[^"]*"|\'[^\']*\')', "", tag)
            if item_lang == active_lang:
                tag = tag[:-1] + ' class="active" aria-current="page">'
            return tag

        return re.sub(
            r'<a\b(?:"[^"]*"|\'[^\']*\'|[^>"\'])*\bdata-lang=(["\'])([a-z]{2})\1(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>',
            update_footer_link,
            nav_block,
        )

    doc = re.sub(
        r'<nav\b[^>]*\bclass=(["\'])[^"\']*\bfooter-lang-links\b[^"\']*\1[^>]*>.*?</nav>',
        update_footer_nav,
        doc,
        flags=re.DOTALL,
    )
    return doc


def rewrite_relative_paths(doc: str) -> str:
    """Prefix relative asset/home paths with ../ for <lang>/index.html pages."""
    doc = re.sub(r'href="(src/css/[^"]+)"', r'href="../\1"', doc)
    doc = re.sub(r'src="(src/js/[^"]+)"', r'src="../\1"', doc)
    doc = re.sub(r'href="(assets/icons/[^"]+)"', r'href="../\1"', doc)
    doc = re.sub(r'src="(qrcode\.min\.js)"', r'src="../\1"', doc)
    doc = re.sub(r'(<a\b[^>]*\bhref=")\./("[^>]*\bclass="navbar-brand"[^>]*>)', r"\1../\2", doc)
    return doc


def render_language_page(template: str, lang: str, d: dict, display_names: dict) -> str:
    doc = template
    direction = "rtl" if lang == "ar" else "ltr"
    page_url = lang_url(lang)
    og_title = d.get("ogTitle") or d["docTitle"]
    og_desc = d.get("ogDesc") or d["metaDesc"]

    # 1. <html> attributes
    doc = re.sub(
        r'<html\b[^>]*>',
        f'<html lang="{lang}" dir="{direction}">',
        doc,
        count=1,
    )

    # 2. <title>, <meta>, canonical, OG, Twitter
    doc = re.sub(
        r"<title>.*?</title>",
        f"<title>{html.escape(d['docTitle'], quote=False)}</title>",
        doc,
        count=1,
        flags=re.DOTALL,
    )
    doc = set_meta_content(doc, "name", "description", d["metaDesc"])
    if d.get("metaKeywords"):
        doc = set_meta_content(doc, "name", "keywords", d["metaKeywords"])
    doc = re.sub(
        r'<link\b[^>]*\brel=(["\'])canonical\1[^>]*>',
        f'<link rel="canonical" href="{page_url}">',
        doc,
        count=1,
    )

    doc = set_meta_content(doc, "property", "og:title", og_title)
    doc = set_meta_content(doc, "property", "og:description", og_desc)
    doc = set_meta_content(doc, "property", "og:url", page_url)
    og_locale = OG_LOCALES[lang]
    if re.search(r'<meta\b[^>]*\bproperty=(["\'])og:locale\1', doc):
        doc = set_meta_content(doc, "property", "og:locale", og_locale)
    else:
        doc = re.sub(
            r'(<meta\b[^>]*\bproperty=(["\'])og:url\2[^>]*>)',
            rf'\1\n    <meta property="og:locale" content="{og_locale}">',
            doc,
            count=1,
        )

    doc = set_meta_content(doc, "name", "twitter:title", og_title)
    doc = set_meta_content(doc, "name", "twitter:description", og_desc)

    # 3. hreflang block
    doc = re.sub(
        r"[ \t]*<!-- HREFLANG_START -->.*?<!-- HREFLANG_END -->",
        build_hreflang_block(),
        doc,
        count=1,
        flags=re.DOTALL,
    )

    # 4. JSON-LD block
    doc = re.sub(
        r"[ \t]*<!-- JSONLD_START -->.*?<!-- JSONLD_END -->",
        build_jsonld_block(lang, d),
        doc,
        count=1,
        flags=re.DOTALL,
    )

    # 5. Pre-render text and HTML elements
    for element_id, dict_key in TEXT_ELEMENT_MAP:
        if dict_key in d and d[dict_key] is not None:
            doc = replace_element_content_by_id(doc, element_id, d[dict_key], is_html=False)

    for element_id, dict_key in HTML_ELEMENT_MAP:
        if dict_key in d and d[dict_key] is not None:
            doc = replace_element_content_by_id(doc, element_id, d[dict_key], is_html=True)

    # 6. Pre-render placeholders & button titles
    doc = set_element_attr_by_id(doc, "urlInput", "placeholder", d["placeholder"])
    doc = set_element_attr_by_id(doc, "businessSearchInput", "placeholder", d["searchPlaceholder"])
    doc = set_element_attr_by_id(doc, "clearBtn", "title", d["trashTitle"])
    doc = set_element_attr_by_id(doc, "searchClearBtn", "title", d["trashTitle"])
    doc = set_element_attr_by_id(doc, "pasteBtn", "title", d["pasteBtn"])

    # 7. Language dropdowns and footer language links
    doc = update_lang_selectors(doc, lang, display_names)

    # 8. Rewrite relative asset URLs for <lang>/index.html
    if lang != "en":
        doc = rewrite_relative_paths(doc)

    return doc


def generate_sitemap(sitemap_path: str) -> None:
    today = date.today().isoformat()
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
        '        xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ]
    for lang in LANGS:
        loc = lang_url(lang)
        priority = "1.0" if lang == "en" else "0.9"
        lines.append("  <url>")
        lines.append(f"    <loc>{loc}</loc>")
        for alt_lang in LANGS:
            lines.append(
                f'    <xhtml:link rel="alternate" hreflang="{alt_lang}" href="{lang_url(alt_lang)}" />'
            )
        lines.append(f'    <xhtml:link rel="alternate" hreflang="x-default" href="{BASE_URL}/" />')
        lines.append(f"    <lastmod>{today}</lastmod>")
        lines.append("    <changefreq>weekly</changefreq>")
        lines.append(f"    <priority>{priority}</priority>")
        lines.append("  </url>")
    lines.append("</urlset>")
    with open(sitemap_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def verify_generated_page(lang: str, html_path: str, d: dict) -> dict:
    with open(html_path, "r", encoding="utf-8") as f:
        content = f.read()

    expected_dir = "rtl" if lang == "ar" else "ltr"
    expected_url = lang_url(lang)

    if f'<html lang="{lang}" dir="{expected_dir}">' not in content:
        raise AssertionError(f"{html_path}: Missing expected <html lang='{lang}' dir='{expected_dir}'>")

    if f'<link rel="canonical" href="{expected_url}">' not in content:
        raise AssertionError(f"{html_path}: Missing expected canonical {expected_url}")

    # Verify all 11 hreflang links
    for alt_lang in LANGS:
        expected_alt = f'<link rel="alternate" hreflang="{alt_lang}" href="{lang_url(alt_lang)}">'
        if expected_alt not in content:
            raise AssertionError(f"{html_path}: Missing hreflang={alt_lang}")
    if f'<link rel="alternate" hreflang="x-default" href="{BASE_URL}/">' not in content:
        raise AssertionError(f"{html_path}: Missing hreflang=x-default")

    # Verify JSON-LD structure and localized FAQs
    ld_match = re.search(
        r'<script type="application/ld\+json" id="structuredDataJsonLd">(.*?)</script>',
        content,
        flags=re.DOTALL,
    )
    if not ld_match:
        raise AssertionError(f"{html_path}: Missing structuredDataJsonLd script")
    ld_data = json.loads(ld_match.group(1).strip().replace("<\\/", "</"))
    if len(ld_data) != 3:
        raise AssertionError(f"{html_path}: Expected 3 JSON-LD blocks, found {len(ld_data)}")
    for block in ld_data:
        if block.get("inLanguage") != lang:
            raise AssertionError(f"{html_path}: JSON-LD block {block.get('@type')} has inLanguage={block.get('inLanguage')}")
    faq_block = next((b for b in ld_data if b.get("@type") == "FAQPage"), None)
    if not faq_block or len(faq_block.get("mainEntity", [])) != 6:
        raise AssertionError(f"{html_path}: Expected 6 FAQPage items")

    # Verify asset references exist on disk relative to html_path directory
    page_dir = os.path.dirname(html_path)
    prefix = "../" if lang != "en" else ""

    css_refs = re.findall(r'href="((?:\.\./)?src/css/[^"]+)"', content)
    js_refs = re.findall(r'src="((?:\.\./)?src/js/[^"]+)"', content)
    qr_refs = re.findall(r'src="((?:\.\./)?qrcode\.min\.js)"', content)
    icon_refs = re.findall(r'href="((?:\.\./)?assets/icons/[^"?]+)(?:\?[^"]*)?"', content)

    all_refs = css_refs + js_refs + qr_refs + icon_refs
    if not css_refs or not js_refs or not qr_refs or not icon_refs:
        raise AssertionError(f"{html_path}: Missing expected asset refs (css={len(css_refs)}, js={len(js_refs)}, qr={len(qr_refs)}, icon={len(icon_refs)})")

    for ref in all_refs:
        if lang != "en" and not ref.startswith("../"):
            raise AssertionError(f"{html_path}: Non-root page reference lacks '../': {ref}")
        if lang == "en" and ref.startswith("../"):
            raise AssertionError(f"{html_path}: Root page reference unexpectedly starts with '../': {ref}")
        target = os.path.normpath(os.path.join(page_dir, ref.replace("/", os.sep)))
        if not os.path.exists(target):
            raise FileNotFoundError(f"{html_path}: Missing referenced target: {target}")

    if lang != "en" and 'href="../" class="navbar-brand"' not in content:
        raise AssertionError(f"{html_path}: navbar-brand should link to '../'")

    if html.escape(d["appTitle"], quote=False) not in content:
        raise AssertionError(f"{html_path}: Missing pre-rendered appTitle")

    dropdown_items = re.findall(
        r'<button\b[^>]*\bclass="([^"]*\blang-dropdown-item\b[^"]*)"[^>]*\bdata-lang="([a-z]{2})"[^>]*>',
        content,
    )
    if len(dropdown_items) != len(LANGS) * 2:
        raise AssertionError(f"{html_path}: Expected {len(LANGS) * 2} lang-dropdown-item buttons, found {len(dropdown_items)}")
    active_dropdown_langs = [dl for cls, dl in dropdown_items if "active" in cls.split()]
    if active_dropdown_langs != [lang, lang]:
        raise AssertionError(f"{html_path}: Expected active dropdown langs {[lang, lang]}, got {active_dropdown_langs}")

    return {
        "css": len(css_refs),
        "js": len(js_refs) + len(qr_refs),
        "icons": len(icon_refs),
        "bytes": os.path.getsize(html_path),
    }


def verify_sitemap(sitemap_path: str) -> None:
    tree = ET.parse(sitemap_path)
    root = tree.getroot()
    ns = {
        "sm": "http://www.sitemaps.org/schemas/sitemap/0.9",
        "xhtml": "http://www.w3.org/1999/xhtml",
    }
    urls = root.findall("sm:url", ns)
    expected_locs = [lang_url(l) for l in LANGS]
    actual_locs = [u.findtext("sm:loc", default="", namespaces=ns) for u in urls]
    if actual_locs != expected_locs:
        raise AssertionError(f"sitemap.xml loc mismatch: {actual_locs} != {expected_locs}")
    for u in urls:
        alts = u.findall("xhtml:link", ns)
        if len(alts) != len(LANGS) + 1:
            raise AssertionError(f"sitemap.xml expected {len(LANGS) + 1} xhtml:link entries, got {len(alts)}")


def main() -> None:
    print("Starting static multilingual SSG build and synchronization...")

    template_path = os.path.join(SRC_DIR, "templates", "web-index.html")
    i18n_path = os.path.join(SRC_DIR, "js", "core", "i18n.js")
    sitemap_path = os.path.join(ROOT_DIR, "sitemap.xml")

    if not os.path.exists(template_path):
        raise FileNotFoundError(f"Missing web template: {template_path}")
    if not os.path.exists(i18n_path):
        raise FileNotFoundError(f"Missing i18n dictionary: {i18n_path}")

    with open(template_path, "r", encoding="utf-8") as f:
        template = f.read()

    i18n, display_names = extract_i18n_data(i18n_path)

    stats = {}
    for lang in LANGS:
        out_path = lang_output_path(lang)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        rendered = render_language_page(template, lang, i18n[lang], display_names)
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(rendered)
        rel_out = os.path.relpath(out_path, ROOT_DIR).replace("\\", "/")
        stats[lang] = verify_generated_page(lang, out_path, i18n[lang])
        print(
            f"  [{lang}] {rel_out} ({stats[lang]['bytes']} bytes) — "
            f"{stats[lang]['css']} CSS, {stats[lang]['js']} JS, {stats[lang]['icons']} icons verified"
        )

    generate_sitemap(sitemap_path)
    verify_sitemap(sitemap_path)
    print(f"\nGenerated and verified sitemap.xml ({len(LANGS)} localized URLs + x-default alternates).")
    print("Web multilingual SSG build completed with 100% integrity!")


if __name__ == "__main__":
    main()

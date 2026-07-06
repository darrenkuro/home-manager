/* mdserve viewer — fetch the served markdown, render it, build the chrome.
 * Single mode is the classic one-document page. Multi mode (several files
 * or a directory) adds a Files section with live full-text search: the
 * server's /search re-reads everything per query — no index, no cache. */
(async function() {
    const main = document.querySelector("main");
    const toc = document.querySelector(".toc");
    const det = toc.querySelector("details");
    const tocList = det.querySelector("ol"); // NOT .toc ol — that would match .files-list
    const filesBox = document.querySelector(".files");
    const searchInput = filesBox.querySelector(".files-search");
    const filesList = filesBox.querySelector(".files-list");
    const resultsList = filesBox.querySelector(".search-results");

    let multi = false;
    let files = [];
    let activeSlug = null;
    let obs = null; // scroll-spy observer for the current document
    let docSeq = 0; // stale-drop guards: only the latest load/search wins
    let searchSeq = 0;
    let currentQuery = "";

    const enc = encodeURIComponent;
    // single mode sends no ?f= at all, so its requests are identical to before
    const docUrl = (path, slug) => multi ? path + "?f=" + enc(slug) : path;

    /* ---- callouts -----------------------------------------------------------
   * Blockquotes that open with a bold label can be upgraded to styled callout
   * components. The machinery below is done; the DESIGN DECISION — which
   * conventions map to which component — is yours.
   *
   * TODO(darren): implement classifyCallout.
   *   `label` is the text of the quote's first <strong>, e.g. "Key idea." or
   *   "MU example (July 2, 2026)." — finance-101.md uses this `> **Label.**`
   *   convention. `quote` is the <blockquote> element itself, in case you want
   *   to look deeper (e.g. its first text node still contains Obsidian-style
   *   "[!tip]" markers if you want to support your vault's syntax too).
   *   Return one of the style.css component classes:
   *     'key'      accent border   (big ideas)
   *     'example'  tinted panel    (worked examples)
   *     'flag'     red border      (warnings, red flags)
   *     'dev'      code panel      (developer notes)
   *   or null to leave it a plain quote. Unmatched quotes degrading to plain
   *   blockquotes IS the fallback behavior — no error handling needed.
   */
    function classifyCallout(label, quote) {
        return null; // ← your call
    }

    /* ---- search ranking -----------------------------------------------------
   * /search returns matching files in scan order (alphabetical by slug) and
   * the machinery below renders whatever order it is given. The DESIGN
   * DECISION — what makes one hit more relevant than another — is yours.
   *
   * TODO(darren): implement rankResults.
   *   `results` is the response's files array: [{slug, name, count, nameMatch,
   *   snippets}] — `count` is how many times the query occurs in the file's
   *   content, `nameMatch` says the filename itself contains it. `q` is the
   *   trimmed query, if you want to weigh exactness. Return the same entries
   *   reordered (never add, drop, or mutate them) — e.g. filename hits first?
   *   highest count? shorter slug on ties? Returning `results` unchanged IS
   *   the fallback behavior — alphabetical order, no error handling needed.
   */
    function rankResults(results, q) {
        return results; // ← your call
    }

    async function loadDoc(slug, { push = false, highlight = null } = {}) {
        const seq = ++docSeq;
        let md;
        try {
            const res = await fetch(docUrl("/doc.md", slug), { cache: "no-store" });
            if (!res.ok) throw new Error("HTTP " + res.status);
            md = await res.text();
        } catch (err) {
            if (seq !== docSeq) return;
            main.innerHTML = "<p><strong>Could not load the document</strong> (" + err.message
                + "). "
                + "Is the mdserve server still running?</p><pre>mdserve &lt;path&gt;...</pre>";
            return;
        }
        if (seq !== docSeq) return;

        // teardown before render: the previous document's scroll-spy + contents
        if (obs) {
            obs.disconnect();
            obs = null;
        }
        tocList.textContent = "";
        main.innerHTML = marked.parse(md);
        if (activeSlug !== null) window.scrollTo(0, 0); // doc switch: back to the top

        // masthead: document name + last-saved time
        try {
            const meta = await (await fetch(docUrl("/meta", slug), { cache: "no-store" })).json();
            if (seq === docSeq) {
                document.querySelector(".eyebrow").textContent = "mdserve · " + meta.file
                    + " · saved "
                    + new Date(meta.mtime).toLocaleString();
            }
        } catch {}
        if (seq !== docSeq) return;

        const h1 = main.querySelector("h1");
        document.title = h1 ? h1.textContent : "mdserve";

        // heading ids + table of contents from h2s
        const seen = {};
        const heads = [...main.querySelectorAll("h2")];
        heads.forEach(h => {
            let id = h.textContent.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
                || "section";
            if (seen[id]) id += "-" + ++seen[id];
            else seen[id] = 1;
            h.id = id;
            const a = document.createElement("a");
            a.href = "#" + id;
            a.textContent = h.textContent;
            const li = document.createElement("li");
            li.appendChild(a);
            tocList.appendChild(li);
        });
        // multi mode keeps the nav (it holds the file list) and hides only Contents
        if (multi) det.hidden = heads.length === 0;
        else toc.hidden = heads.length === 0;

        // relative image paths resolve against the markdown file's own folder;
        // '..' segments must ride in ?p= or the browser normalizes them away
        main.querySelectorAll("img[src]").forEach(img => {
            const src = img.getAttribute("src");
            if (!/^([a-z]+:|\/)/i.test(src)) {
                const f = multi ? "f=" + enc(slug) : "";
                img.src = src.split("/").includes("..")
                    ? "/rel?p=" + enc(src) + (f && "&" + f)
                    : "/rel/" + src + (f && (src.includes("?") ? "&" : "?") + f);
            }
        });
        // external links open in a new tab
        main.querySelectorAll("a[href^=\"http\"]").forEach(a => {
            a.target = "_blank";
            a.rel = "noopener";
        });

        main.querySelectorAll("blockquote").forEach(q => {
            const strong = q.querySelector("p:first-child strong");
            const label = strong ? strong.textContent.trim() : "";
            const cls = classifyCallout(label, q);
            if (!cls) return;
            const aside = document.createElement("aside");
            aside.className = "callout " + cls;
            const lab = document.createElement("p");
            lab.className = "label";
            lab.textContent = label.replace(/[.:]\s*$/, "");
            strong.remove();
            aside.appendChild(lab);
            while (q.firstChild) aside.appendChild(q.firstChild);
            q.replaceWith(aside);
        });

        // scroll-spy on this document's h2s — byId/current live in the observer's
        // closure, so a doc switch discards them with the observer itself
        const byId = {};
        det.querySelectorAll("a[href^=\"#\"]").forEach(a => {
            byId[a.getAttribute("href").slice(1)] = a;
        });
        let current = null;
        obs = new IntersectionObserver(entries => {
            entries.forEach(e => {
                if (e.isIntersecting && byId[e.target.id]) {
                    if (current) current.classList.remove("active");
                    current = byId[e.target.id];
                    current.classList.add("active");
                }
            });
        }, { rootMargin: "-10% 0px -70% 0px" });
        heads.forEach(h => obs.observe(h));

        if (multi) {
            filesList.querySelectorAll("a").forEach(a =>
                a.classList.toggle("active", a.dataset.slug === slug)
            );
        }
        activeSlug = slug;
        if (push) history.pushState({}, "", "?f=" + enc(slug));
        if (highlight) applyHighlights(highlight);
    }

    /* ---- in-document match highlighting ------------------------------------ */
    function clearHighlights() {
        main.querySelectorAll("mark.find").forEach(m => {
            const parent = m.parentNode;
            m.replaceWith(document.createTextNode(m.textContent));
            parent.normalize();
        });
    }

    function applyHighlights(q) {
        const needle = q.toLowerCase();
        if (!needle) return;
        const walker = document.createTreeWalker(main, NodeFilter.SHOW_TEXT);
        const nodes = []; // snapshot first — we mutate as we go
        for (let n = walker.nextNode(); n; n = walker.nextNode()) nodes.push(n);
        let first = null;
        nodes.forEach(node => {
            const text = node.nodeValue;
            const lower = text.toLowerCase();
            let i = lower.indexOf(needle);
            if (i === -1) return;
            const frag = document.createDocumentFragment();
            let pos = 0;
            while (i !== -1) {
                frag.appendChild(document.createTextNode(text.slice(pos, i)));
                const mark = document.createElement("mark");
                mark.className = "find";
                mark.textContent = text.slice(i, i + needle.length);
                frag.appendChild(mark);
                if (!first) first = mark;
                pos = i + needle.length;
                i = lower.indexOf(needle, pos);
            }
            frag.appendChild(document.createTextNode(text.slice(pos)));
            node.replaceWith(frag);
        });
        if (first) first.scrollIntoView({ block: "center" });
    }

    /* ---- multi-mode chrome: file list + live search ------------------------- */
    function fileLink(slug, name) {
        const li = document.createElement("li");
        const a = document.createElement("a");
        a.href = "?f=" + enc(slug); // real href: middle/cmd-click opens a tab
        a.dataset.slug = slug;
        a.textContent = name;
        li.appendChild(a);
        return li;
    }

    function bindList(ol) {
        ol.addEventListener("click", e => {
            if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return; // browser's business
            const a = e.target.closest("a[data-slug]");
            if (!a) return;
            e.preventDefault();
            loadDoc(a.dataset.slug, { push: true, highlight: currentQuery || null });
        });
    }

    function exitSearch() {
        currentQuery = "";
        resultsList.textContent = "";
        resultsList.hidden = true;
        filesList.hidden = false;
    }

    // everything comes from the server as data and enters the DOM as text
    // nodes — no innerHTML of file content anywhere
    function renderResults(data) {
        resultsList.textContent = "";
        const ranked = rankResults(data.files, data.q);
        ranked.forEach(r => {
            const li = fileLink(r.slug, r.name);
            if (r.count > 0) {
                const n = document.createElement("span");
                n.className = "count";
                n.textContent = r.count;
                li.querySelector("a").appendChild(n);
            }
            if (r.snippets.length) {
                const snips = document.createElement("ul");
                snips.className = "snips";
                r.snippets.forEach(s => {
                    const sli = document.createElement("li");
                    sli.appendChild(document.createTextNode(s.before));
                    const m = document.createElement("mark");
                    m.textContent = s.match;
                    sli.appendChild(m);
                    sli.appendChild(document.createTextNode(s.after));
                    snips.appendChild(sli);
                });
                li.appendChild(snips);
            }
            resultsList.appendChild(li);
        });
        const note = document.createElement("li");
        note.className = "no-match";
        if (!ranked.length) {
            note.textContent = "no matches";
            resultsList.appendChild(note);
        } else if (data.truncated) {
            note.textContent = "first " + ranked.length + " files shown";
            resultsList.appendChild(note);
        }
        filesList.hidden = true;
        resultsList.hidden = false;
    }

    let debounce = null;
    function bindSearch() {
        searchInput.addEventListener("input", () => {
            clearHighlights();
            clearTimeout(debounce);
            const q = searchInput.value.trim();
            if (q.length < 2) {
                exitSearch();
                return;
            }
            debounce = setTimeout(async () => {
                const seq = ++searchSeq;
                try {
                    const data = await (await fetch("/search?q=" + enc(q), { cache: "no-store" }))
                        .json();
                    if (seq !== searchSeq) return; // a newer query answered already
                    currentQuery = data.q;
                    renderResults(data);
                } catch {}
            }, 150);
        });
        searchInput.addEventListener("keydown", e => {
            if (e.key === "Enter") {
                const a = resultsList.querySelector("a[data-slug]");
                if (a) a.click(); // open the top-ranked result
            }
        });
        document.addEventListener("keydown", e => {
            if (e.key === "/" && document.activeElement !== searchInput) {
                e.preventDefault();
                searchInput.focus();
            } else if (e.key === "Escape") {
                searchInput.value = "";
                clearTimeout(debounce);
                exitSearch();
                clearHighlights();
                main.focus();
            }
        });
    }

    // sticky TOC: open on wide screens, collapsed on narrow
    const mq = window.matchMedia("(min-width:1060px)");
    const sync = () => {
        det.open = mq.matches;
    };
    sync();
    mq.addEventListener("change", sync);

    /* ---- boot ---------------------------------------------------------------- */
    let listing = null;
    try {
        listing = await (await fetch("/list", { cache: "no-store" })).json();
    } catch {} // older server or race — fall back to single-document behavior
    multi = !!(listing && listing.multi);

    if (multi) {
        files = listing.files;
        document.body.classList.add("multi");
        toc.hidden = false;
        filesBox.hidden = false;
        files.forEach(f => filesList.appendChild(fileLink(f.slug, f.name)));
        bindList(filesList);
        bindList(resultsList);
        bindSearch();

        // back/forward switches documents — but only when the slug actually
        // changed, so in-page #heading history entries don't reload the doc
        window.addEventListener("popstate", () => {
            const s = new URLSearchParams(location.search).get("f")
                || (files[0] && files[0].slug);
            if (s && s !== activeSlug) loadDoc(s);
        });

        if (!files.length) {
            main.innerHTML = "<p><strong>No markdown files found</strong> in the served paths.</p>";
            document.querySelector(".eyebrow").textContent = "mdserve · 0 files";
            return;
        }
        await loadDoc(new URLSearchParams(location.search).get("f") || files[0].slug);
    } else {
        await loadDoc(null);
    }
})();

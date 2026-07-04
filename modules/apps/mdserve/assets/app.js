/* mdserve viewer — fetch /doc.md, render it, build the chrome around it. */
(async function() {
    const main = document.querySelector("main");

    let md;
    try {
        const res = await fetch("/doc.md", { cache: "no-store" });
        if (!res.ok) throw new Error("HTTP " + res.status);
        md = await res.text();
    } catch (err) {
        main.innerHTML = "<p><strong>Could not load the document</strong> (" + err.message + "). "
            + "Is the mdserve server still running?</p><pre>mdserve &lt;file.md&gt;</pre>";
        return;
    }
    main.innerHTML = marked.parse(md);

    // masthead: filename + last-saved time
    try {
        const meta = await (await fetch("/meta", { cache: "no-store" })).json();
        document.querySelector(".eyebrow").textContent = "mdserve · " + meta.file + " · saved "
            + new Date(meta.mtime).toLocaleString();
    } catch {}

    const h1 = main.querySelector("h1");
    document.title = h1 ? h1.textContent : "mdserve";

    // heading ids + table of contents from h2s
    const toc = document.querySelector(".toc");
    const tocList = toc.querySelector("ol");
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
    toc.hidden = heads.length === 0;

    // relative image paths resolve against the markdown file's own folder
    main.querySelectorAll("img[src]").forEach(img => {
        const src = img.getAttribute("src");
        if (!/^([a-z]+:|\/)/i.test(src)) img.src = "/rel/" + src;
    });
    // external links open in a new tab
    main.querySelectorAll("a[href^=\"http\"]").forEach(a => {
        a.target = "_blank";
        a.rel = "noopener";
    });

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

    // sticky TOC: open on wide screens, collapsed on narrow; scroll-spy on h2s
    const det = toc.querySelector("details");
    const mq = window.matchMedia("(min-width:1060px)");
    const sync = () => {
        det.open = mq.matches;
    };
    sync();
    mq.addEventListener("change", sync);

    const byId = {};
    toc.querySelectorAll("a[href^=\"#\"]").forEach(a => {
        byId[a.getAttribute("href").slice(1)] = a;
    });
    let current = null;
    const obs = new IntersectionObserver(entries => {
        entries.forEach(e => {
            if (e.isIntersecting && byId[e.target.id]) {
                if (current) current.classList.remove("active");
                current = byId[e.target.id];
                current.classList.add("active");
            }
        });
    }, { rootMargin: "-10% 0px -70% 0px" });
    heads.forEach(h => obs.observe(h));
})();

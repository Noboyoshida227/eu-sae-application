# Shared, self-contained landing page for the wizard and classic dashboard.
# No remote fonts, image requests, or changes to estimation/server behavior.
sae_landing_page <- function(wizard = FALSE) {
  css <- r"---(#cover_page {
  position: fixed; inset: 0; z-index: 9999; overflow-y: auto;
  color: #f5f9ff; background: radial-gradient(ellipse at 88% 12%, #0861ba 0%, transparent 49%), linear-gradient(125deg, #031b39, #073d7b 68%, #032247);
  font-family: 'Segoe UI', Arial, sans-serif; text-align: left;
}
#cover_page, #cover_page * { box-sizing: border-box; }
#cover_page .sae-cover-shell { max-width: 1536px; min-height: 100%; margin: 0 auto; padding: 26px clamp(24px, 3.4vw, 54px) 18px; display: flex; flex-direction: column; }
#cover_page .sae-cover-header { display:flex; align-items:center; justify-content:space-between; gap:18px; border-bottom:1px solid #3182ba; padding-bottom:24px; }
#cover_page .sae-brand { display:flex; align-items:center; gap:20px; font-size:30px; font-weight:700; letter-spacing:.5px; }
#cover_page .sae-brand-mark { display:grid; grid-template-columns:repeat(3,7px); gap:5px; }
#cover_page .sae-brand-mark i { width:7px; height:7px; border-radius:50%; background:#35e4f5; }
#cover_page .sae-brand-mark i:nth-child(3n) { background:#d5f6ff; }
#cover_page .sae-badge { border:1px solid #75bded; border-radius:6px; padding:9px 17px; font-size:15px; color:#e4f3ff; }
#cover_page .sae-hero { display:grid; grid-template-columns:1.08fr 1fr; align-items:center; gap:24px; padding:48px 0 38px; flex:1; }
#cover_page .sae-eyebrow { color:#72e5ff; font-size:14px; letter-spacing:4px; margin:0 0 26px; }
#cover_page h1 { color:#fff; font-size:clamp(40px,4.85vw,72px); line-height:1.08; font-weight:700; letter-spacing:-2px; margin:0 0 26px; }
#cover_page .sae-description { color:#d9edff; font-size:clamp(17px,1.65vw,23px); line-height:1.55; max-width:640px; margin:0 0 32px; }
#cover_page #enter_app_btn { display:inline-flex; align-items:center; gap:28px; background:linear-gradient(110deg,#91faff,#10e2f3); border:1px solid #8ff7ff; border-radius:8px; color:#022349; font-size:21px; line-height:1.35; font-weight:700; padding:17px 28px; box-shadow:0 0 26px #08c5ec38; cursor:pointer; transition:box-shadow .2s,transform .2s; }
#cover_page #enter_app_btn:hover { background:#a6fbff; transform:translateY(-2px); box-shadow:0 0 34px #08c5ec60; }
#cover_page #enter_app_btn:focus-visible { outline:3px solid white; outline-offset:5px; }
#cover_page .sae-arrow { font-size:29px; line-height:1; font-weight:400; }
#cover_page .sae-setup { color:#b6e2ff; font-size:15px; margin:13px 0 0; }
#cover_page .sae-art { margin:0; min-width:0; }
#cover_page .sae-art svg { display:block; width:100%; height:auto; overflow:visible; }
#cover_page .sae-art figcaption { color:#b6dfff; text-align:center; font-size:12px; line-height:1.5; margin:10px 0 0; }
#cover_page .sae-features { display:grid; grid-template-columns:repeat(3,1fr); gap:22px; padding:0 0 32px; }
#cover_page .sae-feature { display:flex; align-items:flex-start; gap:20px; padding:24px 20px; border:1px solid #359ae1; border-radius:12px; background:linear-gradient(120deg,#004f8d42,#00214a55); box-shadow:inset 0 0 25px #208fff0c; }
#cover_page .sae-icon { flex:none; width:58px; height:58px; padding:14px; border-radius:50%; border:1px solid #258cce; background:#0271b826; color:#56edff; }
#cover_page .sae-icon svg { width:100%; height:100%; fill:none; stroke:currentColor; stroke-width:1.6; }
#cover_page h2 { font-size:25px; line-height:1.2; font-weight:650; margin:0 0 8px; color:#fff; }
#cover_page .sae-feature p { font-size:16px; line-height:1.5; color:#dceeff; margin:0; }
#cover_page .sae-cover-footer { border-top:1px solid #2877af; padding-top:22px; display:flex; flex-wrap:wrap; align-items:center; gap:20px 28px; }
#cover_page .sae-workflow-title { color:#f1f7ff; font-size:17px; padding-right:24px; border-right:1px solid #407291; }
#cover_page .sae-steps { display:flex; flex-wrap:wrap; align-items:center; gap:8px 16px; list-style:none; padding:0; margin:0; color:#bfddf4; font-size:13px; }
#cover_page .sae-steps li:not(:last-child)::after { content:'/'; padding-left:16px; color:#75b7e0; }
#cover_page .sae-release { width:100%; text-align:right; color:#b3d3ed; font-size:11px; margin:0; }
@media (min-width:1100px) and (max-height:850px) {
  #cover_page .sae-cover-shell { padding-top:20px; }
  #cover_page .sae-cover-header { padding-bottom:16px; }
  #cover_page .sae-hero { padding:28px 0; }
  #cover_page h1 { font-size:clamp(40px,4.1vw,60px); }
  #cover_page .sae-art svg { max-height:410px; }
  #cover_page .sae-feature { padding:20px 16px; }
}
@media (max-width:950px) {
  #cover_page .sae-hero { grid-template-columns:1fr; gap:10px; }
  #cover_page .sae-art { max-width:560px; width:100%; margin:0 auto; }
  #cover_page .sae-features { grid-template-columns:1fr; gap:12px; }
  #cover_page .sae-feature { align-items:center; }
  #cover_page h1 { font-size:clamp(40px,7vw,65px); }
  #cover_page .sae-release { text-align:left; }
}
@media (max-width:480px) {
  #cover_page .sae-cover-shell { padding:20px; }
  #cover_page .sae-brand { font-size:24px; gap:12px; }
  #cover_page .sae-badge { font-size:11px; padding:7px 9px; }
  #cover_page .sae-eyebrow { font-size:11px; letter-spacing:2px; }
  #cover_page h1 { letter-spacing:-1.3px; }
  #cover_page .sae-feature { gap:14px; }
  #cover_page .sae-workflow-title { border:0; }
}
@media (prefers-reduced-motion:reduce) {
  #cover_page #enter_app_btn { transition:none; }
  #cover_page #enter_app_btn:hover { transform:none; }
}
)---"
  markup <- r"---(<div id="cover_page"><div class="sae-cover-shell">
<header class="sae-cover-header"><div class="sae-brand"><span class="sae-brand-mark" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></span>EU SAE</div><span class="sae-badge">Research application</span></header>
<main class="sae-hero"><div class="sae-intro"><p class="sae-eyebrow">SMALL AREA ESTIMATION</p>
<h1>Poverty and welfare.<br>A clearer local<br>picture.</h1>
<p class="sae-description">Estimate poverty and mean welfare across small areas, compare years, and understand uncertainty.</p>
{{START_BUTTON}}<p class="sae-setup">{{SETUP_TEXT}}</p></div>
<figure class="sae-art"><svg viewBox="0 0 640 535" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false">
<defs>
<linearGradient id="sae-glass" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#40beff" stop-opacity=".36"/><stop offset=".55" stop-color="#1373ca" stop-opacity=".1"/><stop offset="1" stop-color="#1ce7ff" stop-opacity=".23"/></linearGradient>
<linearGradient id="sae-edge"><stop stop-color="#138dea"/><stop offset=".55" stop-color="#b7ffff"/><stop offset="1" stop-color="#30a8fb"/></linearGradient>
<radialGradient id="sae-glow"><stop stop-color="#26dfff" stop-opacity=".45"/><stop offset="1" stop-color="#1586ff" stop-opacity="0"/></radialGradient>
<filter id="sae-bloom" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="3"/></filter>
</defs>
<ellipse cx="362" cy="460" rx="295" ry="65" fill="url(#sae-glow)"/>
<g stroke="#3192df" stroke-width=".6" opacity=".22"><path d="M10 420 L620 405"/><path d="M10 440 L620 425"/><path d="M10 470 L620 455"/><path d="M10 510 L620 495"/><path d="M320 350 L30 535"/><path d="M320 350 L120 535"/><path d="M320 350 L210 535"/><path d="M320 350 L300 535"/><path d="M320 350 L390 535"/><path d="M320 350 L480 535"/><path d="M320 350 L570 535"/></g><g fill="url(#sae-glass)" stroke="url(#sae-edge)" stroke-width="1.1"><path d="M40 182 L117 162 L117 452 L40 427 Z"/><path d="M92 125 L171 105 L171 475 L92 450 Z"/><path d="M155 88 L228 68 L228 480 L155 455 Z"/><path d="M250 57 L357 37 L357 500 L250 475 Z"/><path d="M370 100 L465 80 L465 471 L370 446 Z"/><path d="M466 137 L550 117 L550 439 L466 414 Z"/><path d="M531 171 L600 151 L600 411 L531 386 Z"/></g><g fill="none"><path d="M-25 330 C145 295, 208 120, 378 195 S520 305, 654 180" stroke="#43dfff" stroke-width="1.2" opacity="0.65"/><path d="M-25 333 C145 297, 208 123, 378 197 S520 307, 654 183" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 336 C145 299, 208 126, 378 199 S520 309, 654 186" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 339 C145 301, 208 129, 378 201 S520 311, 654 189" stroke="#43dfff" stroke-width="1.2" opacity="0.65"/><path d="M-25 342 C145 303, 208 132, 378 203 S520 313, 654 192" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 345 C145 305, 208 135, 378 205 S520 315, 654 195" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 348 C145 307, 208 138, 378 207 S520 317, 654 198" stroke="#43dfff" stroke-width="1.2" opacity="0.65"/><path d="M-25 351 C145 309, 208 141, 378 209 S520 319, 654 201" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 354 C145 311, 208 144, 378 211 S520 321, 654 204" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 357 C145 313, 208 147, 378 213 S520 323, 654 207" stroke="#43dfff" stroke-width="1.2" opacity="0.65"/><path d="M-25 360 C145 315, 208 150, 378 215 S520 325, 654 210" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/><path d="M-25 363 C145 317, 208 153, 378 217 S520 327, 654 213" stroke="#218ef2" stroke-width="0.65" opacity="0.3"/></g><g stroke="#defaff" stroke-width="1.4"><path d="M30.5 300 H125.5 M30.5 295 v10 M125.5 295 v10"/><circle cx="78" cy="300" r="9" fill="#defaff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="78" cy="300" r="5" fill="#defaff"/></g><g stroke="#4defff" stroke-width="1.4"><path d="M78.0 359 H154.0 M78.0 354 v10 M154.0 354 v10"/><circle cx="116" cy="359" r="9" fill="#4defff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="116" cy="359" r="5" fill="#4defff"/></g><g stroke="#defaff" stroke-width="1.4"><path d="M127.5 195 H218.5 M127.5 190 v10 M218.5 190 v10"/><circle cx="173" cy="195" r="9" fill="#defaff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="173" cy="195" r="5" fill="#defaff"/></g><g stroke="#4defff" stroke-width="1.4"><path d="M156.0 252 H264.0 M156.0 247 v10 M264.0 247 v10"/><circle cx="210" cy="252" r="9" fill="#4defff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="210" cy="252" r="5" fill="#4defff"/></g><g stroke="#defaff" stroke-width="1.4"><path d="M236.5 102 H343.5 M236.5 97 v10 M343.5 97 v10"/><circle cx="290" cy="102" r="9" fill="#defaff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="290" cy="102" r="5" fill="#defaff"/></g><g stroke="#4defff" stroke-width="1.4"><path d="M281.5 401 H368.5 M281.5 396 v10 M368.5 396 v10"/><circle cx="325" cy="401" r="9" fill="#4defff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="325" cy="401" r="5" fill="#4defff"/></g><g stroke="#defaff" stroke-width="1.4"><path d="M327.0 229 H451.0 M327.0 224 v10 M451.0 224 v10"/><circle cx="389" cy="229" r="9" fill="#defaff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="389" cy="229" r="5" fill="#defaff"/></g><g stroke="#4defff" stroke-width="1.4"><path d="M381.0 319 H493.0 M381.0 314 v10 M493.0 314 v10"/><circle cx="437" cy="319" r="9" fill="#4defff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="437" cy="319" r="5" fill="#4defff"/></g><g stroke="#defaff" stroke-width="1.4"><path d="M431.0 155 H531.0 M431.0 150 v10 M531.0 150 v10"/><circle cx="481" cy="155" r="9" fill="#defaff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="481" cy="155" r="5" fill="#defaff"/></g><g stroke="#4defff" stroke-width="1.4"><path d="M150.0 435 H240.0 M150.0 430 v10 M240.0 430 v10"/><circle cx="195" cy="435" r="9" fill="#4defff" opacity=".4" filter="url(#sae-bloom)"/><circle cx="195" cy="435" r="5" fill="#4defff"/></g></svg><figcaption>A visual interpretation of estimation and uncertainty</figcaption></figure></main>
<section class="sae-features" aria-label="Analysis capabilities"><article class="sae-feature"><span class="sae-icon" aria-hidden="true"><svg viewBox="0 0 34 34"><path d="M5 26V18h4v8M14 26V11h4v15M23 26V4h4v22"/></svg></span><div><h2>Estimate</h2><p>Poverty and mean welfare using UFH and MFH models.</p></div></article><article class="sae-feature"><span class="sae-icon" aria-hidden="true"><svg viewBox="0 0 34 34"><circle cx="16" cy="6" r="4"/><circle cx="6" cy="25" r="4"/><circle cx="26" cy="25" r="4"/><path d="M14 10L8 21M18 10l6 11M10 25h12"/></svg></span><div><h2>Compare</h2><p>Explore differences across areas and years.</p></div></article><article class="sae-feature"><span class="sae-icon" aria-hidden="true"><svg viewBox="0 0 34 34"><path d="M18 28H5V3h15l6 6v9M20 3v7h6M9 14h10M9 19h5"/><circle cx="23" cy="24" r="5"/><path d="M27 28l4 4"/></svg></span><div><h2>Understand</h2><p>Review uncertainty, diagnostics, and benchmarked estimates.</p></div></article></section>
<footer class="sae-cover-footer"><span class="sae-workflow-title">From data to insight</span>{{WORKFLOW}}
<p class="sae-release">Independent release candidate for review and testing</p></footer></div></div>)---"
  button <- shiny::actionButton(
    "enter_app_btn",
    label = htmltools::tagList("Start an analysis", htmltools::tags$span(
      class = "sae-arrow", `aria-hidden` = "true", htmltools::HTML("&rarr;")
    ))
  )
  markup <- sub("{{START_BUTTON}}", as.character(button), markup, fixed = TRUE)
  markup <- sub("{{SETUP_TEXT}}", if (wizard) "Guided setup in six steps" else "All analysis settings in one workspace", markup, fixed = TRUE)
  markup <- sub("{{WORKFLOW}}", if (wizard) "<ol class=\"sae-steps\" aria-label=\"Guided setup steps\"><li>Data</li><li>Mapping</li><li>Indicator</li><li>Models</li><li>AI Assistant</li><li>Review &amp; Run</li></ol>" else "<span class=\"sae-setup\">Data, models, diagnostics, and results</span>", markup, fixed = TRUE)
  htmltools::tagList(htmltools::tags$style(htmltools::HTML(css)), htmltools::HTML(markup))
}

# Shared catalogue -> application menu and report-template path regression.
local({
  source("R/workbench_ui.R", local = TRUE)
  catalogue <- jsonlite::fromJSON("docs/maintenance/navigation.json", simplifyVector = FALSE)
  menu <- sae_resource_links(getwd())
  links <- vapply(menu, function(x) x$href, character(1))
  stopifnot("eusae-docs/INDEX.html" %in% links)
  targets <- sub("^eusae-docs/", "docs/", utils::URLdecode(sub("#.*$", "", links)))
  stopifnot(all(file.exists(targets)))
  for (language in c("English", "Polish", "Greek")) {
    guides <- Filter(function(x) startsWith(x$id, "guide") && x$id != "guidelines" && x$language == language, catalogue$items)
    stopifnot(length(guides) == 3L,
              all(vapply(guides, function(x) startsWith(x$path, paste0("docs/instructions/", language, "/")), logical(1))),
              all(vapply(guides, function(x) file.exists(x$editable), logical(1))))
    stopifnot(all(paste0("eusae-", vapply(guides, function(x) x$path, character(1))) %in% links))
  }
  stopifnot(any(grepl("MOLINA_ROMERO_DEVIATIONS_w5p.html", links, fixed = TRUE)),
            any(grepl("W5P_VALIDATION_RECEIPT.html", links, fixed = TRUE)),
            !any(grepl("\\.md$", links)))
  # A renamed or removed catalogue document cannot silently remain a menu link.
  fixture <- tempfile("navigation-menu-");dir.create(file.path(fixture, "docs", "maintenance"), recursive = TRUE)
  file.copy("docs/maintenance/navigation.json", file.path(fixture, "docs", "maintenance"))
  stopifnot(length(sae_resource_links(fixture)) == 0L)
  unlink(fixture, recursive = TRUE)
  source("R/report_export.R", local = TRUE)
  stopifnot(file.exists("docs/templates/report_reference.docx"),
            grepl('"docs", "templates", "report_reference.docx"', paste(deparse(body(sae_render_word_report)),collapse=" "), fixed = TRUE))
  cat("PASS: navigation catalogue/menu languages, targets, missing files and Word template path.\n")
})

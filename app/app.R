library(shiny)
library(bslib)
library(magrittr)

# Load helper functions
source("helpers.R")

# UI
ui <- page_sidebar(
  title = "CNV Analýza",

  bg = "#fafafac7",

  tags$head(
    tags$script(HTML("document.title = 'CNV Analýza';")),
    tags$style(HTML("
      .navbar.navbar-static-top {
        background: #007BC2;
        background: linear-gradient(90deg, rgba(0, 123, 194, 1) 0%, rgba(255, 255, 255, 1) 25%); # nolint
      }
      .navbar-brand {
        color: #ffffff !important;
        font-weight: 700 !important;
        font-size: 26px !importnat;
      }
      .navbar.navbar-static-top {
        background: #007BC2;
        background: linear-gradient(90deg,rgba(0, 123, 194, 1) 0%, rgba(255, 255, 255, 1) 25%); # nolint
      }
      .navbar-brand {
        color: #ffffff !important;
        font-weight: 700 !important;
      }
      .btn-file {
        font-size: 16px;
        width: 100%;
      }
      .btn-file:hover {
        font-size: 16px;
      }
      .input-group,
      .input-group-prepend {
        width: 100% !important;
        padding-top: 0px !important;
        margin-top: 0px;
      }
      .gender-row {
        display: flex;
        align-items: center;
        gap: 0 !important; 
        margin-bottom: 5px;
        padding: 0;
      }

      .gender-label {
        width: 120px;
      }

      .gender-select .form-group {
        margin: 0;
        width: 80px;
      }

      .card-body.bslib-gap-spacing {
        gap: 0 !important;
      }
    "))
  ),

  sidebar = sidebar(
    tags$h5(textOutput("text"), style = "color: #007BC2; font-weight: bold; font-size: 20px; margin-top: 10px"), # nolint
    fileInput("file", NULL, multiple = TRUE, accept = ".txt", buttonLabel = "Vybrat soubory", # nolint
              placeholder = "Nevybrán žádný soubor", width = "100%"),
    tags$style("
      .btn-file { font-size: 16px; }
      .btn-file:hover { font-size: 16px; }
      .btn-file { width: 100%; }
      .input-group { width: 100% !important; margin-top: 0px; padding-top: 0px !important; } # nolint
      .input-group-prepend { width: 100% !important; padding-top: 0px !important; } # nolint
    "),
    downloadButton("downloadCoverage", "Coverage", class = "btn-lg btn-primary"), # nolint
    downloadButton("downloadCNVM", "CNV M", class = "btn-lg btn-primary"),
    downloadButton("downloadCNVZ", "CNV Z", class = "btn-lg btn-primary"),
    tags$hr(),
    tags$a(
      href = "https://www.omim.org", target = "_blank",
      style = "font-weight: bold; font-size: 16px; display: block; margin-top: 10px;", # nolint
      icon("database"), "OMIM databáze"
    )
  ),

  card(
    uiOutput("gender_input"),
    uiOutput("action_button")
  ),

  card(
    navset_card_tab(
      nav_panel("Table", tableOutput("coverage_table")),
      nav_panel("CNV M", tableOutput("cnv_m")),
      nav_panel("CNV Z", tableOutput("cnv_z"))
    )
  )
)

# Server logic
server <- function(input, output, session) {
  output$text <- renderText({
    if (is.null(input$file)) return("Kód várky: ")
    base_names <- sub("(_cov\\.txt|_\\(paired\\)_Target_Region_Coverage\\.txt)$", "", input$file$name) # nolint
    codes <- substr(base_names, nchar(base_names) - 1, nchar(base_names))
    paste("Kód várky: ", unique(codes), collapse = ", ")
  })

  sample_id <- reactive({
    req(input$file)
    gsub("(_cov\\.txt|_\\(paired\\)_Target_Region_Coverage\\.txt)$", "", input$file$name) # nolint
  })

  output$gender_input <- renderUI({
    ids <- sample_id()
    lapply(ids, function(id) {
      div(class = "gender-row",
        div(class = "gender-label", strong(id)),
        div(class = "gender-select",
          selectInput(
            inputId = paste0("pohlavi", id),
            label = NULL,
            choices = c("Muž" = "M", "Žena" = "Z"),
            width = "80px",
            selectize = TRUE
          )
        )
      )
    })
  })

  final_data <- reactiveVal()
  pohlavi_data <- reactiveVal()
  cnv_m_data <- reactiveVal()
  cnv_z_data <- reactiveVal()
  submit_status <- reactiveVal("ready")

  output$action_button <- renderUI({
    req(input$file)
    actionButton(
      "submit",
      label = if (submit_status() == "processing") "Zpracovávám..." else "Zpracovat", # nolint
      icon = if (submit_status() != "processing") icon("check") else NULL,
      class = if (submit_status() == "processing") "btn btn-primary" else "btn btn-success", # nolint
      style = "margin-top: 5px; width: 200px; font-size: 20px; padding: 10px;",
      disabled = submit_status() == "processing"
    )
  })

  observeEvent(input$submit, {
    req(input$file)
    submit_status("processing")

    file_list <- input$file$datapath
    filenames <- input$file$name
    ids <- sample_id()
    pohlavi <- sapply(ids, function(id) input[[paste0("pohlavi", id)]])
    pohlavi_df <- data.frame(ID = ids, Gender = pohlavi)
    pohlavi_data(pohlavi_df)
    if (!dir.exists("../data_output")) dir.create("../data_output")
    #write.csv(pohlavi_df, "../data_output/pohlavi.csv", row.names = FALSE)

    showNotification("Soubory coverage a CNV se generují.", type = "message")

    selected_cols_list <- lapply(seq_along(file_list), function(i) {
      tryCatch({
        df <- read.delim(file_list[i], check.names = FALSE)
        if (nrow(df) < 1 || ncol(df) < 15) stop()
        selected <- df[, 15, drop = FALSE]
        base_name <- tools::file_path_sans_ext(gsub("_cov\\.txt$", "", filenames[i])) # nolint
        gender <- input[[paste0("pohlavi", ids[i])]]
        colnames(selected) <- paste0(gender, "_", base_name)
        return(selected)
      }, error = function(e) {
        showNotification(paste("Chyba u souboru:", filenames[i]), type = "error") # nolint
        return(NULL)
      })
    })

    result <- do.call(cbind, selected_cols_list)
    prvni_trisloupce <- read.delim(file_list[1], check.names = FALSE)[, 1:3]
    combined <- cbind(prvni_trisloupce, result)
    colnames(combined) <- trimws(gsub("Mean coverage", "", colnames(combined), fixed = TRUE)) # nolint
    final_data(combined)

    #tryCatch({
    #  write.table(combined, "../data_output/coverage.csv", col.names = TRUE, row.names = FALSE, sep = ";") # nolint
    #}, error = function(e) {
    #  showNotification("Chyba při ukládání coverage.csv", type = "error")
    #})

    # CNV logic
    coverage <- final_data()
    pohlavi <- pohlavi_data()
    m <- colnames(coverage)[grepl("^M_", colnames(coverage))]
    z <- colnames(coverage)[grepl("^Z_", colnames(coverage))]
    omimgeny <- load_omim_file()

    if (length(m) > 0) {
      normalized_m <- normalize_coverage(coverage[, m, drop = FALSE])
      coverage_m_final <- cbind(coverage[, c("Chromosome","Region","Name")], Index = seq.int(nrow(coverage)), normalized_m) # nolint

      coverage_cols <- coverage_m_final[, -c(1:3), drop = FALSE]

      if (ncol(coverage_cols) >= 1) {
        m_values <- abs(coverage_cols) > 0.25
        greater_m <- coverage_m_final[rowSums(m_values, na.rm = TRUE) > 0, ]
      } else {
        greater_m <- coverage_m_final[FALSE, ]
      }

      greater_m <- annotate_with_omim(greater_m, omimgeny)
      #write.table(greater_m, "../data_output/CNV_M.csv", sep = ";", row.names = FALSE) # nolint
      cnv_m_data(greater_m)
    }

    if (length(z) > 0) {
      normalized_z <- normalize_coverage(coverage[, z, drop = FALSE])
      coverage_z_final <- cbind(coverage[, c("Chromosome","Region","Name")], Index = seq.int(nrow(coverage)), normalized_z) # nolint

      coverage_cols <- coverage_z_final[, -c(1:3), drop = FALSE]

      if (ncol(coverage_cols) >= 1) {
        z_values <- abs(coverage_cols) > 0.25
        greater_z <- coverage_z_final[rowSums(z_values, na.rm = TRUE) > 0, ]
      } else {
        greater_z <- coverage_z_final[FALSE, ]
      }

      greater_z <- annotate_with_omim(greater_z, omimgeny)
      #write.table(greater_z, "../data_output/CNV_Z.csv", sep = ";", row.names = FALSE) # nolint
      cnv_z_data(greater_z)
    }

    submit_status("ready")
  })

  # Tables
  output$coverage_table <- renderTable({ final_data() })
  output$cnv_m <- renderTable({ cnv_m_data() })
  output$cnv_z <- renderTable({ cnv_z_data() })

  # Downloads
  output$downloadCoverage <- downloadHandler(
    filename = function() { "coverage.csv" },
    content = function(file) {
      write.csv2(final_data(), file, row.names = FALSE, quote = FALSE, fileEncoding = "UTF-8") # nolint
    }
  )
  output$downloadCNVM <- downloadHandler(
    filename = function() { "CNV_M.csv" },
    content = function(file) {
      write.csv2(cnv_m_data(), file, row.names = FALSE, quote = FALSE, fileEncoding = "UTF-8") # nolint
    }
  )
  output$downloadCNVZ <- downloadHandler(
    filename = function() { "CNV_Z.csv" },
    content = function(file) {
      write.csv2(cnv_z_data(), file, row.names = FALSE, quote = FALSE, fileEncoding = "UTF-8") # nolint
    }
  )
}

shinyApp(ui = ui, server = server)

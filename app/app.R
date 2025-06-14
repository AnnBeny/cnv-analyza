library(shiny)
library(bslib)
library(magrittr)

# Load helper functions
source("helpers.R")

# --- UI ---
ui <- page_sidebar(
  title = "CNV Analýza",

  bg = "#fafafac7",

  # html
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

  # Side panel
  sidebar = sidebar(
    # Kód várky
    tags$h5(textOutput("text"), style = "color: #007BC2; font-weight: bold; font-size: 20px; margin-top: 10px"), # nolint
    # Upload button
    fileInput("file", NULL, multiple = TRUE, accept = ".txt", buttonLabel = "Vybrat soubory", # nolint
              placeholder = "Nevybrán žádný soubor", width = "100%"),
    tags$style("
      .btn-file { font-size: 16px; }
      .btn-file:hover { font-size: 16px; }
      .btn-file { width: 100%; }
      .input-group { width: 100% !important; margin-top: 0px; padding-top: 0px !important; } # nolint
      .input-group-prepend { width: 100% !important; padding-top: 0px !important; } # nolint
    "),
    # Download button
    downloadButton("downloadCoverage", "Coverage", class = "btn-lg btn-primary"), # nolint
    downloadButton("downloadCNVM", "CNV M", class = "btn-lg btn-primary"),
    downloadButton("downloadCNVZ", "CNV Z", class = "btn-lg btn-primary"),
    tags$hr(),
    # Link to OMIM database
    tags$a(
      href = "https://www.omim.org", target = "_blank",
      style = "font-weight: bold; font-size: 16px; display: block; margin-top: 10px;", # nolint
      icon("database"), "OMIM databáze"
    )
  ),

  # top tab
  card(
    uiOutput("aktualizace"),
    #uiOutput("gender_input"),
    #uiOutput("action_button")
  ),
  # bottom tab
  card(
    navset_card_tab(
      nav_panel("Coverage", DT::dataTableOutput("coverage_table")),
      nav_panel("CNV Muži", DT::dataTableOutput("cnv_m")),
      nav_panel("CNV Ženy", DT::dataTableOutput("cnv_z"))
    )
  )
)

######################################################################################################################## # nolint

# --- Server logic ---
server <- function(input, output, session) {

  # actualization
  output$aktualizace <- renderUI({
    if (is.null(input$file)) {
      card(
        tags$div(
          class = "text-left",
          style = "margin-bottom: 10px;",
          tags$p("Aktualizace", style = "font-weight: bold; color: #007BC2; font-size: 16px;"), # nolint
          tags$p("Do CNV_M a CNV_Z přidán sloupce Row_id pro číslování řádků odpovídající původnímu pořadí.", style = "font-size: 14px;"), # nolint
          tags$p("Automatické přejmenování souborů s příponou '(paired) Target Region Coverage'.", style = "font-size: 14px;"), # nolint
        ),
      )
    } else {
      card(
        uiOutput("gender_input"),
        uiOutput("action_button")
      )
    }
  })

  # Name of samples without suffixes
  sample_id <- reactive({
    req(input$file)
    gsub("_cov\\.txt|| \\(paired\\) Target Region Coverage\\.txt$", "", input$file$name) # nolint
  })

  # Take the last two letters from name of samples
  output$text <- renderText({
    req(sample_id())
    if (is.null(input$file)) return("Kód várky: ")
    codes <- substr(sample_id(), nchar(sample_id()) - 1, nchar(sample_id())) # nolint
    paste("Kód várky: ", unique(codes), collapse = ", ")
  })

  # Button for choosing gender
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

  # Button to process input and run analysis
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

  # --- Makeing Tables Coverages and CNV ---
  observeEvent(input$submit, {
    req(input$file)
    submit_status("processing")

    withProgress(message = "Zpracování CNV...", value = 0, {
      submit_status("processing")
      incProgress(0.1, detail = "Načítání souborů...")

      file_list <- input$file$datapath
      filenames <- input$file$name
      ids <- sample_id()
      pohlavi <- sapply(ids, function(id) input[[paste0("pohlavi", id)]])
      pohlavi_df <- data.frame(ID = ids, Gender = pohlavi)
      pohlavi_data(pohlavi_df)
      if (!dir.exists("../data_output")) dir.create("../data_output")
      #write.csv(pohlavi_df, "../data_output/pohlavi.csv", row.names = FALSE) # nolint

      #showNotification("Soubory coverage a CNV se generují.", type = "message") # nolint

      incProgress(0.3, detail = "Generování coverage dat...")

      selected_cols_list <- lapply(seq_along(file_list), function(i) {
        tryCatch({
          df <- read.delim(file_list[i], check.names = FALSE)
          if (nrow(df) < 1 || ncol(df) < 15) stop()
          selected <- df[, 15, drop = FALSE]
          base_name <- tools::file_path_sans_ext(gsub("_cov\\.txt|| \\(paired\\) Target Region Coverage\\.txt$", "", filenames[i])) # nolint
          gender <- input[[paste0("pohlavi", ids[i])]]
          colnames(selected) <- paste0(gender, "_", base_name)
          return(selected)
          print(gender)
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

      incProgress(0.6, detail = "Normalizace CNV M...")

      # CNV logic
      coverage <- final_data()
      pohlavi <- pohlavi_data()
      row_id <- seq.int(nrow(coverage))
      m <- colnames(coverage)[grepl("^M_", colnames(coverage))]
      z <- colnames(coverage)[grepl("^Z_", colnames(coverage))]
      omimgeny <- load_omim_file()

      # Men
      if (length(m) > 0) {

        # Normalize coverage data for M samples
        normalized_m <- normalize_coverage(coverage[, m, drop = FALSE])
        cat("---normalized_m--- \n")
        print(head(normalized_m, 5))
        cat("normalized_m has", nrow(normalized_m), "rows and", ncol(normalized_m), "columns\n") # nolint

        # Add Row_id to coverage data
        coverage$Row_id <- seq.int(nrow(coverage))
        coverage_m_final <- cbind(
          coverage[, c("Chromosome", "Region", "Name", "Row_id")], # check the name of the columns # nolint
          normalized_m
        )
        #coverage_m_final <- cbind(coverage[, c(1:3)], Row_id = seq.int(nrow(coverage)), normalized_m) # nolint
        cat("---coverage_m_final--- \n")
        print(head(coverage_m_final, 5))

        # Extract coverage columns for M samples
        coverage_cols <- coverage_m_final[, -c(1:4), drop = FALSE]
        cat("---coverage_cols--- \n")
        print(head(coverage_cols, 5))

        # Calculate m_values based on coverage columns
        m_values <- abs(coverage_cols) > 0.25
        cat("---m_values--- \n")
        print(head(m_values, 5))

        # Filter rows where any m_value is greater than 0
        greater_m <- coverage_m_final[rowSums(m_values, na.rm = TRUE) > 0, ]
        cat("---greater_m--- \n")
        print(head(greater_m, 5))

        # Annotate greater_m with OMIM data
        greater_m <- annotate_with_omim(greater_m, omimgeny)
        #write.table(greater_m, "../data_output/CNV_M.csv", sep = ";", row.names = FALSE) # nolint
        cnv_m_data(greater_m)
      }

      incProgress(0.8, detail = "Normalizace CNV Z...")

      # Women
      if (length(z) > 0) {

        # Normalize coverage data for Z samples
        normalized_z <- normalize_coverage(coverage[, z, drop = FALSE])

        # Add Row_id to coverage data
        coverage$Row_id <- seq.int(nrow(coverage))
        coverage_z_final <- cbind(
          coverage[, c("Chromosome", "Region", "Name", "Row_id")], # check the name of the columns # nolint
          normalized_z
        )
        #coverage_z_final <- cbind(coverage[, c(1:3)], Row_id = row_id, normalized_z) # nolint

        # Extract coverage columns for Z samples
        coverage_cols <- coverage_z_final[, -c(1:4), drop = FALSE]

        # Calculate z_values based on coverage columns
        z_values <- abs(coverage_cols) > 0.25

        # Filter rows where any z_value is greater than 0
        greater_z <- coverage_z_final[rowSums(z_values, na.rm = TRUE) > 0, ]

        # Annotate greater_z with OMIM data
        greater_z <- annotate_with_omim(greater_z, omimgeny)
        #write.table(greater_z, "../data_output/CNV_Z.csv", sep = ";", row.names = FALSE) # nolint
        cnv_z_data(greater_z)
      }
      incProgress(1, detail = "Hotovo")
    })
    # Update the status of the submit button
    submit_status("ready")
  })

  # --- Tables into bottom tab ---
  #output$coverage_table <- renderTable({ final_data() })
  #output$cnv_m <- renderTable({ cnv_m_data() })
  #output$cnv_z <- renderTable({ cnv_z_data() })

  # Render coverage table
  output$coverage_table <- DT::renderDataTable({
    req(final_data())
    df <- final_data()
    validate(need(nrow(df) > 0, "Žádná data pro pokrytí"))
    DT::datatable(
      df,
      options = list(
        pageLength = 25,
        scrollX = TRUE
      )
    )
  })

  # Render CNV M and CNV Z tables
  output$cnv_m <- DT::renderDataTable({
    req(cnv_m_data())
    df <- cnv_m_data()
    validate(need(nrow(df) > 0, "Žádná data pro CNV M"))
    DT::datatable(
      df,
      options = list(
        pageLength = 25,
        scrollX = TRUE
      )
    )
  })
  output$cnv_z <- DT::renderDataTable({
    req(cnv_z_data())
    df <- cnv_z_data()
    validate(need(nrow(df) > 0, "Žádná data pro CNV Z"))
    DT::datatable(
      df,
      options = list(
        pageLength = 25,
        scrollX = TRUE
      )
    )
  })

  # --- Download handlers for coverage and CNV data
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
cat("Server logic loaded successfully.\n")

# Run the application
shinyApp(ui = ui, server = server)

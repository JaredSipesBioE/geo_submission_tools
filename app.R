#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)
# needed for getting files
library(shinyFiles)
# used for activating buttons as needed
library(shinyjs)
library(bslib)
library(DT)

library(writexl)

library(awn)

# Separate Page for Functions Used
source('utils.R')

# sets max file size to 30 MB to allow pkc file uploads

options(shiny.maxRequestSize = 30 * 1024^2)

ui <- page_navbar(
  
  #allow Awesome notifications (AWN) to be used
  
  # https://github.com/JohnCoene/awn
  
  
  ##### PANEL 1 UI - WORKSHEETS ######
  # Upload the Worksheets, Merge and Remove Unneeded 
  nav_panel("Worksheets",
            
            tags$head(tags$script(src = "message-handler.js")),
            
            # Sidebar for Uploading the Worksheets
            sidebarLayout(
              sidebarPanel(
                fileInput("upload_wksht", label = "Upload Worksheet Files", multiple = TRUE, accept = c(".txt")),
                
                numericInput("skip", "Rows to skip", 14, min = 0),
                
                downloadButton("download_worksheets", "Download Merged Worksheets", class = "btn-block")
                
              ),
              
              # View merged worksheets, filter by desired category, and delete unneeded rows
              
              mainPanel(
                
                # Display a list of the uploaded worksheets
                #tableOutput("wksht_files"),
                
                DT::DTOutput("merged_table"),
                
                actionButton("delete_rows_button", "Delete Selected Rows"),
                
                actionButton("rstr_tbl_bt", "Restore Original Table"),
                
                # debugging 
                # verbatimTextOutput('rows_selected'),
                # 
                # verbatimTextOutput('row_names')
              )
              )
                          
            ),
  
  ##### Panel 2 UI - Annotation Files ####
  
  nav_panel("Annotation File", 
            
            # Sidebar for Uploading the Worksheets
            sidebarLayout(
              sidebarPanel(
                fileInput("upload_annotations", label = "Upload Annotation File", multiple = F, accept = c(".xlsx")),
                
                checkboxInput("checkbox_skip_merge", "Skip merge and use annotation file as is?", FALSE),
                
              ),
              
            # View Uploaded Annotation File and Choose Columns to Include or Exclude
              
              mainPanel(
                
                # Display the uploaded annotations for viewing
                DT::DTOutput("annotations_table"),
                
                
                
              )
            )
  ), 
  
  ##### Panel 3 UI - Merge Annotations and Worksheet ####
  
  nav_panel("Merge Worksheets and Annotations", 
            
            DT::DTOutput("annot_wksht_merged"),
            
            downloadButton("download_merged_annotations", "Download Merged Annotations", class = "btn-block")
            
            # mainPanel(
            #   DT::DTOutput("annot_wksht_merged")
            # )
  ), 
  
  #### Panel 4 UI - DCC and FASTQ Files ####
  
  nav_panel("DCC and FASTQ Files", 
            
            
            shinyjs::useShinyjs(),
            
            useAwn(),
            
            sidebarLayout(

              sidebarPanel(
                shinyDirButton("dir_dcc", "Choose folder containing ALL dccs and FASTQ.gz files", "Select a folder"),
                
                verbatimTextOutput("path_dcc", placeholder = TRUE),
                
                
                shinyDirButton("dir_out", "Choose folder to move unwanted DCC and FASTQ Files to", "Select a folder"),
                
                verbatimTextOutput("path_out", placeholder = TRUE),
                
                # the following button is controlled by shinyjs
                # should be greyed out and inactive unless both file locations are selected.
                
                actionButton("move_files", "Move Files")
                
              ),
              
              mainPanel(
                
                DT::DTOutput("DCC_FastQ_Mappings"),
                        
                downloadButton("download_dcc_map", "Download Table", class = "btn-block")
                        
                ),
              
              
              
              
              #### NOTE FOR LATER 
              
              # Add Warnings: Num DCC Files Not found, Num FASTQ Files not found. Is Num FASTQ Even? Warn if odd.
              
              # Might want to Modify Table to have a warnings column and highlight issues in red.
              
            )),
  
  
  #### Panel 5 UI - GEO Sample records ####
  
  nav_panel("Create GEO Sample Records", 
            
            sidebarLayout(
              
              sidebarPanel(
              
              # Upload PKC File
                
                fileInput("upload_pkc", label = "Upload PKC File", multiple = F, accept = c(".pkc")),
              
              # Set Library Strategy, Molecule, single or paired-end, instrument model, and description 
              
                fluidRow(
                  textInput("library_strat", label = "Library Strategy", value = "Spatial Transcriptomics"),
              
                  textInput("organism", label = "Organism", value = "Homo sapiens"),
                ),
                
                fluidRow(
                  
                  selectInput("molecule", label = "Molecule     ",
                              list("total RNA", "polyA RNA", "nuclear RNA", "cytoplasmic RNA", "genomic DNA", "protein", "other")),
              
                  selectInput("single_or_paired", label = "Single or Paired-end?", list("paired-end", "single-end")),
                
                  selectInput("instrument_model", label = "Instrument Model", choices = get_instrument_list())
                              
                ),
              
              # Set Tissue, Cell Line, and Cell Type Columns
              
                textOutput("choose_req_attributes"),
              
              fluidRow(
              
                selectInput("tissue_col", label = "Select Tissue (or NA)", choices = NULL),
              
                selectInput("cell_line_col", label = "Select Cell Line (or NA)", choices = NULL),
              
                selectInput("cell_type_col", label = "Select Cell Type (or NA)", choices = NULL)
                
                ),
              
              # Choose Other Attribute Columns to Include
              
                
                checkboxGroupInput("checkbox_attribute_cols", "Check other Attribute Columns to include",
                                   choices = NULL, selected = NULL)
              
              ), 
              
              mainPanel(
                
                # Generated Table of GEO Sample Records
                  
                  DT::DTOutput("GEO_sample_records"),
                  
                  downloadButton("download_GEO_sample", "Download Table", class = "btn-block")
                
              ),
              
              )
            
            ), 
  
  
  #### Panel 6 UI - Calculate MD5 Checksums ####
  
  nav_panel("Calculate MD5 Checksums",
            
            sidebarLayout(
              
              sidebarPanel(
                
                shinyDirButton("select_save_dir", "Select Location to Save All Files", "Select a folder"),
                
                verbatimTextOutput("path_save_dir"),
                
                actionButton("copy_files", "Copy DCC and FASTQ Files to Selected Folder"),
                
                actionButton("gen_checksum", "Generate MD5 Checksums"),
                
              ),
              
              mainPanel(
                fluidRow(DT::DTOutput("MD5_Checksum_FASTQ_Table"),
                         
                         DT::DTOutput("MD5_Checksum_Other_Table")
                         
                         ),
                
                downloadButton("download_MD5_Checksum", "Download Tables", class = "btn-block")
                
                
              )
            )),
  
  title = "GEO Submission Tools", 
  id = "page", 
)

server <- function(input, output, session) {
  
  rows_to_delete <- reactiveValues(rows = c())
  
  
  # Expose Vector as reactive expression
  
  stored_rows_to_delete <- reactive({
    rows_to_delete$rows
  })
  
 #### Panel 1 - Upload Worksheets #####
  
  wksheet_data <- reactive({
    
    # require that the worksheets be uploaded
    req(input$upload_wksht)
    
    # read in all of the wksht files
    dfs <- read_in_wkshts(files = input$upload_wksht, skip = input$skip)
    
    #return dfs
    dfs
    
  })
  
 #### Panel 1 - Output Wksheets ####
  
  ## List all uploaded files
  output$wksht_files <- renderTable(input$upload_wksht)
  
  # merge the worksheets
  wksheet_merged <- reactive({
    rows <- stored_rows_to_delete()
    
    req(wksheet_data())
    
    data <- merge_wksht_files(files = wksheet_data())
    
    if(length(rows) > 0){
      data <- data[!row.names(data) %in% rows, ]
    }
    #return data
    data
  })
  
  
  output$merged_table <- DT::renderDT({
    
    
    data <- wksheet_merged()
    
  
    DT::datatable(data, selection = "multiple", 
               options = list(extensions = 'Scroller',
                              deferRender = TRUE,
                              scrollY = 500,
                              scroller = TRUE)
               )
  })
  
  
  # Allow the user to download the merged worksheets
  output$download_worksheets <- downloadHandler(
    
    filename = "merged_worksheets.xlsx",
    content = function(file) {
      write_xlsx(wksheet_merged(), file)
    }
    
  )
    

  
  
  #### Panel 1 - Delete Table Rows Logic #####

  ##### DEBUGGING Selected rows #####
  
  # # print the selected indices
  # output$rows_selected = renderPrint({
  #   s = input$merged_table_rows_selected
  #   if (length(s)) {
  #     cat('These rows were selected:\n\n')
  #     cat(s, sep = ', ')
  #   }
  # })
  # 
  # 
  # output$row_names = renderPrint({
  #   s = input$merged_table_rows_selected
  #   if (length(s)) {
  #     cat('These row names were selected:\n\n')
  #     df <- wksheet_merged()
  #     r <- rownames(df[s, ])
  #     cat(r, sep = ', ')
  #   }
  # })
  
  
  # Observe Delete Button Click
  
  observeEvent(input$delete_rows_button, {
    
    new_vals <- isolate(input$merged_table_rows_selected)
    
    req(length(input$merged_table_rows_selected) > 0)
    
    df <- wksheet_merged()
    
    new_rows <- rownames(df[new_vals, ])
    
    rows_to_delete$rows <- c(rows_to_delete$rows, new_rows)

  })
  
  # Observe Restore Button Click
  
  observeEvent(input$rstr_tbl_bt, {
    
    rows_to_delete$rows <- c()
    
  })
  
  
  
  #### Panel 2 - Upload Annotations File ####
  
  
  annotations_data <- reactive({
    
    # require that the worksheets be uploaded
    req(input$upload_annotations)
    
    annot_path <- input$upload_annotations$datapath[1]
    
    # read in the annotation files
    df <- readxl::read_xlsx(path = annot_path)
    
    #return annotations
    df
    
  })
  
  
  
  output$annotations_table <- DT::renderDT({
    data <- annotations_data()
    DT::datatable(data, selection = "multiple", 
                  options = list(extensions = 'Scroller',
                                 deferRender = TRUE,
                                 scrollY = 500,
                                 scroller = TRUE)
    )
  })
  
  
  #### Panel 3 - Merge Worksheets and Annotations ######

  annot_wksh_merge_data <- reactive({
    
    # require that the annotations be uploaded

    req(input$upload_annotations)
  
    # if checkbox is marked, using annotations directly, otherwise, merge if wksheets uploaded. 
    
    if(input$checkbox_skip_merge){
      df <- annotations_data()
    } else{
      req(input$upload_wksht)
      
      df <- merge_wksht_annot(wksht = wksheet_merged(), annot = annotations_data())
      
    }
    
    df

    
  })
  
  output$annot_wksht_merged <- DT::renderDT({
    data <- annot_wksh_merge_data()
    DT::datatable(data, selection = "multiple", 
                  options = list(extensions = 'Scroller',
                                 deferRender = TRUE,
                                 scrollY = 500,
                                 scroller = TRUE,
                                 fillContainer = TRUE)
    )
  })
  
  
  # Allow the user to download the resulting merged file 
  output$download_merged_annotations<- downloadHandler(
    
    filename = "merged_annotations.xlsx",
    content = function(file) {
      write_xlsx(annot_wksh_merge_data(), file)
    }
    
  )
  
  
  #### Panel 4 - DCCs and FASTQ Files #####
  
  volumes <- c(Home = fs::path_home(), "R Installation" = R.home(), getVolumes()())
  
  
  ## Panel 4 - Side Tab ##
  
  # for the FastQ and dcc directory
  
  shinyDirChoose(input, "dir_dcc", roots = volumes, session = session)
  
  # Get path of directory
  
  selected_dir_dcc <- reactive({
    req(input$dir_dcc)
    parseDirPath(volumes, input$dir_dcc)
  })
  
  # print path of directory
  
  output$path_dcc <- renderPrint({
    # returns input if available, otherwise, returns default message
    
    if(is.integer(input$dir_dcc)){
      "Please select a file."
    } else{
      selected_dir_dcc()

    }
    
  })
  
  
  
  # for the output directory to save unwanted files to
  
  shinyDirChoose(input, "dir_out", roots = volumes, session = session)
  
  # Get path of directory to move unwanted dcc and fastq files to
  
  selected_dir_out <- reactive({
    req(input$dir_out)
    parseDirPath(volumes, input$dir_out)
  })
  
  # print path of directory out
  
  output$path_out <- renderPrint({
    req(selected_dir_out())
    selected_dir_out()
  })
  
  
  ## Activate the action button when conditions are met
  
  observe({
    
    # if either file selection has no input
    if(is.integer(input$dir_dcc) | is.integer(input$dir_out)){
      # disable the dir dcc button
      shinyjs::disable("move_files")
    } else{
      shinyjs::enable("move_files")
    }
  })
  
  # output$move_files <- renderUI({
  #   
  #   # if both files are selected
  #     if(is.integer(input$dir_dcc) | is.integer(input$dir_out)){
  #       "To move files, please select both files." 
  #     } else{
  #       selected_dir_dcc()
  #     
  #   }
  #   
  #     # make action button appear
  #     # actionButton("move_files", "Move Files")
  #   
  #    # otherwise, print default message about need to select files.
  #   
  # })

  
  ## Panel 4 - Main Tab ##
  
  # create DF from DCC inputs
  DCC_table_data <- reactive({
    req(input$dir_dcc)
    req(input$upload_wksht)
    req(input$upload_annotations)
    
    DCC_table <- make_dcc_fastq_mappings(folder = selected_dir_dcc(), merged_annotations = annot_wksh_merge_data())
    
    DCC_table
  })
  
  
  
  
  
  # Create DCC FASTQ Table
  output$DCC_FastQ_Mappings <- DT::renderDT({
    data <- DCC_table_data()
    DT::datatable(data, selection = "multiple", 
                  options = list(extensions = 'Scroller',
                                 deferRender = TRUE,
                                 scrollY = 500,
                                 scroller = TRUE,
                                 fillContainer = TRUE)
    )
  })
  
  # allows user to download the table generated
  
  output$download_dcc_map <- downloadHandler(
    
    filename = "DCC_FASTQ_Table.xlsx",
    content = function(file) {
      write_xlsx(DCC_table_data(), file)
    }
    
  )
  
  ## Panel 4: Move unwanted files to new location
  
  observeEvent(input$move_files, {
    
    dcc_file_table <- DCC_table_data()
    dcc_files_dir <- selected_dir_dcc()
    
    n_files <- length(list.files(path = dcc_files_dir, pattern = "\\.(dcc|gz)$", recursive = T, full.name = T))
    
    # count all of the non-na values. 
    n_keep <- sum(!is.na(unlist((dcc_file_table[2:ncol(dcc_file_table)]))))
    
    n_files_to_move <- n_files - n_keep
    
    message <- paste0("Are you sure you wish to move ", as.character(n_files_to_move), " files to the selected folder?")
      
    ask(
      "confirm_move", # id of input
      p(message)
    )
  })
  
  observeEvent(input$confirm_move, {
    #print(input$confirm_move)
    
    if(input$confirm_move){
      # get the dcc file table, dir input, and dir output
      dcc_file_table <- DCC_table_data()
      dcc_files_dir <- selected_dir_dcc()
      dcc_files_out <- selected_dir_out()
      
      # extract the list of SampleIDs to keep
      dcc_list_keep <- dcc_file_table$Sample_ID
      
      
      # get all dcc and fastq files
      files_all <- list.files(path = dcc_files_dir, pattern = "\\.(dcc|gz)$", recursive = T, full.name = T)

      # create list of files to keep
      
      keep_list <- unlist(dcc_file_table[2:ncol(dcc_file_table)], use.names = FALSE)

      
      # create data table,set all files not in keep_list to move
      
      files_to_move <- as.data.frame(files_all) |> mutate(move = !(basename(files_all) %in% keep_list))
      
      files_to_move <- files_to_move[files_to_move$move, ]
      
      for(file in files_to_move$files_all){
        
        filename <- basename(file)
        extension <- tools::file_ext(filename)
        name <- tools::file_path_sans_ext(filename)
        
        
        dest <- file.path(dcc_files_out, basename(file))
        # adds numbers if multiple duplicate files are detected.
        i <- 1
        
        while(file.exists(dest)){
          new_filename <- paste0(name, "_", i, ".", extension)
          dest <- file.path(dcc_files_out, new_filename)
          i <- i + 1
        }
        # if files have duplicate names, do not overwrite. 
        file.rename(from = file, to = dest)
      }
      
    }
    
  })
  
  
  
  
  #### Panel 5 - GEO Sample table ####
  
  
  # Reactive that gets the possible attribute columns available. 
  
  attribute_cols_list <- reactive({
    
    # req that the merged annotation file exist. 
    
    # get the list of column names, excluding columns that cannot be attributes, like Sample_ID
    
  })
  
  
  # Updates selection inputs based on the attribute col list
  
  observeEvent(attribute_cols_list(), {

    # get the choices
    
    #  updateSelectInput(inputId = "ordernumber", choices = choices)
    
    
  })
  
  geo_sample_data <- reactive({
    
    # require the annotations and the DCC datafiles
    req(annot_wksh_merge_data())
    req(DCC_table_data())
    
    
    sample_records <- create_GEO_sample_records(annotations = annot_wksh_merge_data(),
                                                library_strat = input$library_strat,
                                                organism = input$organism,
                                                molecule = input$molecule, 
                                                single_or_paired = input$single_or_paired,
                                                instr_model = input$instrument_model)

  
    
    sample_records <- mutate(sample_records, Sample_ID = library_name)
    
    dcc_table <- DCC_table_data() 
    
    
    # merge the tables by Sample_ID
    
    sample_records <- dplyr::left_join(sample_records, dcc_table,
                                                    by = c("Sample_ID")
                                       )
    
    sample_records
    })
  
  output$GEO_sample_records <- DT::renderDT({
    
    
    data <- geo_sample_data()
    
    
    DT::datatable(data, selection = "multiple", 
                  options = list(extensions = 'Scroller',
                                 deferRender = TRUE,
                                 scrollY = 500,
                                 scroller = TRUE,
                                 fillContainer = TRUE)
    )
  })
  
  
  # col_order <- c("library_name", "title", "library strategy", "organism", "cell type", "segment label", 
  #                "Roi", "molecule", "single or paired-end", "instrument model", "description")
  
  
  
  
  ###### Panel 6 - Generate Checksums ####### 
  
  
  # Checksums for FASTQ Files
  MD5_checksums_fastq <- reactive({
    
    req(DCC_table_data())
    req(input$dir_dcc)
    
    calculate_MD5_checksums(folder, fastq = T)
    
  })
  
  # Checksums for Processed Data Files
  MD5_checksums_other <- reactive({
    
    req(DCC_table_data())
    req(input$dir_dcc)
    
    calculate_MD5_checksums(folder, fastq = F)
  
  })
  
  
  

}

shinyApp(ui = ui, server = server)
#####################################################
# Project: geo_submission_tools
# File: utils.R
# Purpose of file: supporting functions for app
#####################################################

library(dplyr)

read_in_wkshts <- function(files, skip){
  
  dfs <- lapply(seq_len(nrow(files)), function(i){
    
    # double check only .txt uploaded
    
    ext <- tools::file_ext(files$name[i])
    
    # Reads if .txt, otherwise error
    
    df <- switch(ext,
                 txt = read.table(files$datapath[i], sep = "\t", skip = skip, header = T, fill = T, na.strings = c("NA")),
                 validate("Invalid filetype, only .txt allowed."))
    
    # clean up Excel ="value" formula artifacts
    df[] <- lapply(df, function(col){
      # remove =" at beginning and " at end, capturing only middle
      if(is.character(col)) sub('^="(.*)"$', '\\1', col) else col
    }
    )
    
    df
    
  })
  
  return(dfs)
    
}


# The following function takes the input worksheet files and merges them to create one worksheet file. 

merge_wksht_files <- function(files){
  
  dfs <- files
  req(length(dfs) > 0)
  
  all_worksheets <- do.call(dplyr::bind_rows, dfs)|>
    
    # add in column names containing important information
    mutate(
      construct = "directPCR",
      instrument = "nextSeq 500/550",
      read_pattern = "27x27",
      expected_neg = 
        ifelse(trimws(tolower(Slide.Name)) == "no template control", 1, 0)
    )
  
  
  return(all_worksheets)
  
}



# The following function merges the worksheet and annotation files


merge_wksht_annot <- function(wksht = NA, annot = NA){
  
  # Rename using a named vector and `all_of()`
  lookup <- c(Scan.Name = "Scan Name", Segment = "Segment (Name/ Label)", Roi = "ROI_ID")
  annot <- annot |> dplyr::rename(all_of(lookup))
  
  
  merged_df <- dplyr::left_join(wksht, annot,
                     by = c("Scan.Name", "Roi", "Segment")
                     )
  
  return(merged_df)
}


# The following function takes .dccs files and matches them to fastq.gz files



make_dcc_fastq_mappings <- function(folder, merged_annotations){
  
  # list all fastq.gz files
  
  fastq_files_all <- list.files(folder, pattern = ".gz$", recursive = T) |> basename()
  
    
  # list all dcc files 
  
  dcc_files_all <- list.files(folder, pattern = ".dcc$", recursive = T) |> basename()
  
  # Initialize an empty list
  dcc_fastq_map <- list()
  
  
  # Loop through .dcc files
  
  for(ID in merged_annotations$Sample_ID){
    #for (dcc in list.files(folder_dccs, pattern = paste0(plate, ".*\\.dcc$"))) {
      # Extract the identifier (everything before ".dcc")
    
    
    # Find matching dcc files

    if(length(dcc_files_all[grepl(ID, dcc_files_all)])){
      matches_dcc <- dcc_files_all[grepl(ID, dcc_files_all)]
    }else{
      matches_dcc <- "WARNING: DCC NOT Found"
    }
      
    # Find matching fastq files
    
    if(length(fastq_files_all[grepl(ID, fastq_files_all)])){
      matches_fastq <- fastq_files_all[grepl(ID, fastq_files_all)]
    }else{
      matches_fastq <- "WARNING: FASTQ NOT Found"
    }
    
      
    # Store in the list with Sample_ID as name
    dcc_fastq_map[[ID]] <- c(matches_dcc, matches_fastq)
    
  }
  
  # Convert the list into a data frame
  max_fastq <- max(sapply(dcc_fastq_map, length))-1 # Find max number of files per ID, subtracting the DCC file
  df <- data.frame(matrix(ncol = max_fastq + 2, nrow = length(dcc_fastq_map)))
  
  # Set column names
  colnames(df) <- c("Sample_ID", "DCC_File", paste0("FASTQ_File_", seq_len(max_fastq)))
  
  # Fill in the data frame
  df$Sample_ID <- names(dcc_fastq_map)  # First column: Sample IDS
  
  for (i in seq_along(dcc_fastq_map)) {
    
    list <- dcc_fastq_map[[i]]  # Get the list for this sample ID
    num_fastq <- length(list)   # Count the fastq files
    
    if (num_fastq > 0) {
      df[i, 2:(num_fastq + 1)] <- list  # Assign fastq files safely
    }
  }
  
  
  return(df)
  
  
}

# 
# tissue_col = input$tissue_col,
# cell_line_col = input$cell_line_col,
# cell_type_col = input$cell_type_col


# The following function creates the GEO Sample Records Table 
# dcc_fastq_map

create_GEO_sample_records <- function(annotations, dcc_fastq_map, PKC_file_name, annot_file_name,
                                      library_strat, organism, molecule, single_or_paired, instr_model,
                                      tissue_col, cell_line_col, cell_type_col, other_attr_cols){
  # generate the titles for all samples 
  
  annotations <- annotations |> mutate(title = if_else(
    expected_neg == 1,
    # value if TRUE
    paste0("No_Template_Control_", Sample_ID),
    # value if FALSE
    paste(Slide.Name, "ROI", Roi, Segment, sep = "_")
    )
  )

  
  # generate the df
  
  df <- data.frame(library_name = annotations$Sample_ID,
                   title = annotations$title,
                   library_strategy = library_strat,
                   organism = organism)
  
  

  # Add Tissue, Cell Line, Cell Type Column, Segment, ROI, and Other Attribute Cols as needed
  
  cols <- c(Tissue = tissue_col, `Cell Line` = cell_line_col,  `Cell Type` = cell_type_col, Segment = "Segment", ROI = "Roi")
  
  # Add other attribute columns if needed
  
  if(!is.null(other_attr_cols)){
    extra_cols <- setNames(other_attr_cols, other_attr_cols)
    
    cols <- c(cols, extra_cols)
  }
  
  
  for(i in seq_along(cols)){
    col <- cols[i]
    name <- names(cols[i])
    if(col != "NA"){
      vals <- as.character(annotations[[col]]) # convert to character to avoid coercing column 
      vals[is.na(vals) | trimws(vals) == ""] <- "NA" # make NA or whitespace "NA" for GEO
      df[[name]] <- vals
    }
  }
  
  # Add other required cols and processed datafile columns
  
  df <- data.frame(df,
    molecule = molecule,
    single_or_paired = single_or_paired,
    instrument_model = instr_model,
    description = "",
    DCC_File = dcc_fastq_map$DCC_File,
    PKC_File = PKC_file_name,
    Annot_File = annot_file_name,
    check.names = FALSE # prevent changing column names 
  )

  
  # Add other attribute columns selected

  
  # merge df with rest of dcc_fastq_map
  
  
  
  df_new <- dplyr::left_join(df, 
                             dcc_fastq_map[, !names(dcc_fastq_map) %in% c("Sample_ID")], # get rid of Sample ID
                             by = c("DCC_File")
  )
  
  
  return(df_new)

}




# the following function calculates MD5 Checksums for the Required Files

# set fastq to T to get the fastq checksums, otherwise get checksumts for processed files only. 


calculate_MD5_checksums <- function(folder, fastq = F){
  
  # Set folder path
  folder_path <- folder
  
  # Get all files in the folder
  
  if(fastq){
    files_to_process <- list.files(folder_path, pattern = ".gz$", full.names = TRUE)
  }
  else{
    files_to_process <- list.files(folder_path, pattern = ".dcc$|.xlsx$|.pkc$", full.names = TRUE)
  }
  
  check_files <- sapply(files_to_process, digest, algo = "md5", file = TRUE)
  
  # Create a data frame with filenames and their checksums
  checksum_data <- data.frame(
    FileName = basename(files_to_process),
    MD5_Checksum = check_files,
    stringsAsFactors = FALSE
  )
  
  return(checksum_data)
}



#### list of instruments

get_instrument_list <- function(){
  
  instruments <- list(
    "NextSeq 500",
    "NextSeq 550",
    "HiSeq X Five",
    "HiSeq X Ten",
    "Illumina Genome Analyzer",
    "Illumina Genome Analyzer II",
    "Illumina Genome Analyzer IIx",
    "Illumina HiScanSQ",
    "Illumina HiSeq 1000",
    "Illumina HiSeq 1500",
    "Illumina HiSeq 2000",
    "Illumina HiSeq 2500",
    "Illumina HiSeq 3000",
    "Illumina HiSeq 4000",
    "Illumina HiSeq X",
    "Illumina MiSeq",
    "Illumina MiniSeq",
    "Illumina NovaSeq 5000",
    "Illumina NovaSeq 6000",
    "Illumina NovaSeq X",
    "Illumina NovaSeq X Plus",
    "Illumina iSeq 100",
    "MiSeq i100",
    "MiSeq i100 Plus",
    "NextSeq 1000",
    "NextSeq 2000",
    "BGISEQ-100",
    "BGISEQ-1000",
    "BGISEQ-2000",
    "BGISEQ-50",
    "BGISEQ-500",
    "CycloneSEQ",
    "MGISEQ-200",
    "MGISEQ-2000",
    "MGISEQ-2000RS",
    "DNBSEQ-E25",
    "DNBSEQ-G400",
    "DNBSEQ-G400 FAST",
    "DNBSEQ-G50",
    "DNBSEQ-G99",
    "DNBSEQ-T1+",
    "DNBSEQ-T10x4",
    "DNBSEQ-T10x4RS",
    "DNBSEQ-T20x2",
    "DNBSEQ-T7",
    "DNBSEQ-T7+",
    "Ion GeneStudio S5",
    "Ion GeneStudio S5 Plus",
    "Ion GeneStudio S5 Prime",
    "Ion Torrent Genexus",
    "Ion Torrent PGM",
    "Ion Torrent Proton",
    "Ion Torrent S5",
    "Ion Torrent S5 XL",
    "GridION",
    "MinION",
    "PromethION",
    "Onso",
    "PacBio RS",
    "PacBio RS II",
    "Revio",
    "Sequel",
    "Sequel II",
    "Sequel IIe",
    "AmCareSeq-2000",
    "BioelectronSeq 4000",
    "Complete Genomics",
    "DA8600",
    "Element AVITI",
    "Element VITARI",
    "GS111",
    "FASTASeq 300",
    "GenoCare 1600",
    "GenoLab M",
    "SURFSeq 5000",
    "SURFSeq Q",
    "Gene+Seq-2000",
    "G-seq500",
    "Helicos HeliScope",
    "HYK-PSTAR-IIA",
    "QNome-3841",
    "QNome-3841hex",
    "QPinnacle2",
    "QPursue-6k",
    "QPursue-6khex",
    "Salus EVO",
    "Salus Pro",
    "Saluseq Nimbo",
    "G4",
    "Tapestri",
    "UG 100",
    "UG 200",
    "Sentosa SQ301",
    "AB 5500 Genetic Analyzer",
    "AB 5500xl Genetic Analyzer",
    "AB 5500xl-W Genetic Analysis System",
    "AB SOLiD 3 Plus System",
    "AB SOLiD 4 System",
    "AB SOLiD 4hq System",
    "AB SOLiD PI System",
    "AB SOLiD System",
    "AB SOLiD System 2.0",
    "AB SOLiD System 3.0",
    "454 GS",
    "454 GS 20",
    "454 GS FLX",
    "454 GS FLX Titanium",
    "454 GS FLX+",
    "454 GS Junior"
  )
  
  return(instruments)
  
}



#### list of excluded column names

# the following identifies columns in the merged annotations that should not be included as options for attribute columns

get_excluded_cols <- function(){
  
  excluded_names <- c(
    "Sample_ID",
    "Slide.Name",
    "Scan.Name",
    "Panel",
    "Roi",
    "Segment",
    "Aoi",
    "Area",
    "Tags",
    "Nuclei",
    "ROI.Coordinate.X",
    "ROI.Coordinate.Y",
    "Scan.Date",
    "Scan.Width",
    "Scan.Height",
    "Scan.Offset.X",
    "Scan.Offset.Y",
    "X.v1.0..Cancer.Transcriptome.Atlas",
    "construct",
    "instrument",
    "read_pattern",
    "expected_neg",
    "ROI (Label)",
    "Segment Tags",
    "Custom Segment Name",
    "LOT_Cancer_Transcriptome_Atlas_1_0",
    "Scan_ID"
  )
  
  return(excluded_names)
  
}

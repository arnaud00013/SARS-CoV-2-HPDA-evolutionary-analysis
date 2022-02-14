#@Author=Arnaud NG
#This script analyses SARS-CoV-2 evolution in epitopes during the second wave of the COVID-19 pandemic

#import libraries
library("ggplot2")
library("seqinr")
library("grid")
library("RColorBrewer")
library("randomcoloR")
library("gplots")
library("lmPerm")
library("ggpubr")
library("gridExtra")
library("RColorBrewer")
library("indicspecies")
library("tidyr")
library("Cairo")
library("parallel")
library("foreach")
library("doParallel")
library("infotheo")
library("VennDiagram")
library("Biostrings")
library("session")
#import script arguments
output_workspace <- as.character(commandArgs(TRUE)[1])
nb_cpus <- as.integer(commandArgs(TRUE)[2])

depth_data_wp <- output_workspace
#name of the reference genome fasta file
fasta_refseq_filename <- "MN908947_3.fasta"
#import reference fasta
genome_refseq <- seqinr::getSequence(object = toupper(read.fasta(paste0(output_workspace,fasta_refseq_filename),seqtype = "DNA",as.string = TRUE,forceDNAtolower = FALSE)),as.string = TRUE)[[1]]
v_orfs_of_interest <- c("orf1a","orf1b","S","E","M","N")
df_epitopes <- read.csv2(file = paste0(output_workspace,"Epitopes_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
df_epitopes$Genomic_start <- as.integer(df_epitopes$Genomic_start)
df_epitopes$Genomic_End <- as.integer(df_epitopes$Genomic_End)

v_lst_id_peptide_seq_in_order <- 1:length(sort(unique(df_epitopes$Peptide),decreasing = FALSE))
names(v_lst_id_peptide_seq_in_order) <- sort(unique(df_epitopes$Peptide),decreasing = FALSE)

#position Inter (prevalence >=0.1)
v_positions_inter <- c(174, 204, 222, 241, 313, 335, 445, 593, 913, 936, 1059, 1163, 1191, 1210, 1344, 1513, 1758, 1912, 1947, 1987, 2416, 2453, 2509, 2973,
 3037, 3096, 3256, 3267, 3311, 3602, 3871, 4002, 4006, 4291, 4346, 4543, 5144, 5170, 5388, 5575, 5622, 5629, 5949, 5986, 6023, 6285, 6286, 6445, 6807, 6941,
 6954, 7528, 7540, 7767, 7926, 8047, 8076, 8083, 8140, 8179, 8603, 8683, 8917, 8983, 9246, 9286, 9430, 9526, 9745, 9802, 10078, 10097, 10265, 10319, 10323, 10376,
 10615, 10741, 10870, 11083, 11132, 11230, 11396, 11401, 11417, 11497, 11533, 11557, 11747, 11781, 12067, 12119, 12134, 12162, 12455, 12988, 13536, 13667, 13993,
 14202, 14408, 14676, 14708, 14805, 15279, 15324, 15406, 15480, 15598, 15753, 15766, 15957, 15972, 16176, 16242, 16260, 16377, 16647, 16887, 16889, 17019, 17104,
 17572, 17615, 18028, 18167, 18424, 18555, 18877, 19017, 19524, 19542, 19718, 19839, 19862, 19960, 19999, 20178, 20268, 20451, 20661, 21222, 21255, 21304, 21575,
 21614, 21637, 21800, 21855, 22020, 22051, 22088, 22205, 22227, 22346, 22377, 22388, 22444, 22879, 22992, 23063, 23248, 23271, 23311, 23401, 23403, 23593, 23604,
 23644, 23709, 23731, 24076, 24088, 24334, 24506, 24814, 24910, 24914, 25049, 25062, 25437, 25494, 25505, 25563, 25606, 25614, 25617, 25710, 25720, 25757, 25878,
 25879, 25881, 25889, 25904, 25906, 25907, 25996, 26060, 26313, 26424, 26681, 26735, 26801, 26801, 26876, 26972, 27384, 27434, 27513, 27769, 27800, 27865, 27866,
 27944, 27964, 27972, 28001, 28048, 28087, 28095, 28111, 28133, 28169, 28253, 28280, 28281, 28282, 28310, 28472, 28651, 28657, 28706, 28725, 28759, 28821, 28854,
 28869, 28881, 28882, 28883, 28887, 28932, 28975, 28975, 28977, 29095, 29179, 29227, 29366, 29386, 29399, 29402, 29427, 29445, 29466, 29543, 29555, 29645, 29686,
 29692, 29710, 29734, 29771, 29779, 29785)

#Get list of genomic region and positions
v_orfs <- c("5'UTR", "orf1a", "orf1b", "S","ORF3a","ORF3b","ORF3c","E","M","ORF6","ORF7a", "ORF7b","ORF8", "N", "ORF9c","ORF10","3'UTR")
v_start_orfs <- c(1, 266, 13468, 21563, 25393, 25814, 25524,26245, 26523, 27202, 27394, 27756,27894, 28274, 28734, 29558, 29675)
names(v_start_orfs) <- v_orfs
v_end_orfs <- c(265, 13468, 21555, 25384, 26220, 25882, 25697, 26472, 27191, 27387, 27759, 27887,28259, 29533, 28955, 29674, 29903)
names(v_end_orfs) <- v_orfs
find_ORF_of_mutation <- function(the_site_position){
  indx <- which((v_start_orfs<=the_site_position)&(v_end_orfs>=the_site_position))[1]
  if (length(indx)==0){
    return(NA)
  }else{
    return(v_orfs[indx])
  }
}
v_orfs_length <- v_end_orfs - v_start_orfs + 1
palette_orfs_epitopes <- c("orf1a"="red","orf1b"="blue","S"="green3","E"="orange","M"="grey","N"="purple")

v_genes_with_unique_product <- c(paste0("NSP",1:10),paste0("NSP",12:16), "S","ORF3a","ORF3b","ORF3c","E","M","ORF6","ORF7a", "ORF7b","ORF8", "N", "ORF9c", "ORF10")
v_start_genes <- c(265+1,265+541,265+2455,265+8290,265+9790,265+10708,265+11578,265+11827,265+12421,265+12760,265+13176,265+15972,265+17775,265+19356,265+20394,21563, 25393, 25814, 25524, 26245, 26523, 27202, 27394, 27756, 27894, 28274,28734, 29558)
names(v_start_genes) <- v_genes_with_unique_product
v_end_genes <- c(265+540,265+2454,265+8289,265+9789,265+10707,265+11577,265+11826,265+12420,265+12759,265+13176,265+15971,265+17774,265+19355,265+20393,265+21287,25384, 26220,25882, 25697, 26472, 27191, 27387, 27759, 27887, 28259,29533, 28955, 29674)
names(v_end_genes) <- v_genes_with_unique_product
find_gene_of_mutation <- function(the_site_position){
  indx <- which((v_start_genes<=the_site_position)&(v_end_genes>=the_site_position))[1]
  if (length(indx)==0){
    return(NA)
  }else{
    return(v_genes_with_unique_product[indx])
  }
}
v_genes_length <- v_end_genes - v_start_genes + 1


#find protein site from mutation name
find_prot_site_from_mut_name <- function(the_mut){
  the_mut <- gsub(pattern = "Stop",replacement = "*",x = the_mut,fixed = T)
  v_positions_split <- as.vector(gregexpr(pattern = ";",text = the_mut,fixed = T)[[1]])
  return(as.integer(substr(the_mut,v_positions_split[1]+2,v_positions_split[2]-2)))
}
#find protein from mutation name
find_prot_from_mut_name <- function(the_mut){
  the_mut <- gsub(pattern = "Stop",replacement = "*",x = the_mut,fixed = T)
  v_positions_split <- as.vector(gregexpr(pattern = ";",text = the_mut,fixed = T)[[1]])
  return(substr(the_mut,v_positions_split[2]+1,v_positions_split[3]-1))
}

#Get list of S protein domains positions (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7266584/)
v_S_protein_domains <- c("NTD", "RBD", "SD1", "SD2","CR","HR1","CH-BH","SD3","HR2-TM-CT")
v_start_S_protein_domains <- c(18,331,528,589,846,912,985,1072,1163)
names(v_start_S_protein_domains) <- v_S_protein_domains
v_end_S_protein_domains <- c(306,528,589,677,912,985,1072,1163,1273)
names(v_end_S_protein_domains) <- v_S_protein_domains
find_S_protein_domain_of_mutation <- function(the_site_position){
  indx <- which((v_start_S_protein_domains<=the_site_position)&(v_end_S_protein_domains>=the_site_position))[1]
  if (length(indx)==0){
    return(NA)
  }else{
    return(v_S_protein_domains[indx])
  }
}
v_S_protein_domains_length <- v_end_S_protein_domains - v_start_S_protein_domains + 1

df_epitopes$Mapping_region <- vapply(X = df_epitopes$Genomic_End,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
df_epitopes$Mapping_region <- factor(as.character(df_epitopes$Mapping_region),intersect(v_orfs,df_epitopes$Mapping_region))
df_epitopes$peptide_id <- paste0(df_epitopes$Mapping_region,"_",unname(v_lst_id_peptide_seq_in_order[df_epitopes$Peptide]))
df_epitopes <- df_epitopes[,c("peptide_id",names(read.csv2(file = paste0(output_workspace,"Epitopes_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)))]
#exclude possible annotation mistakes
df_epitopes <- subset(df_epitopes,vapply(X = 1:nrow(df_epitopes),FUN = function(i) (return(grepl(pattern = df_epitopes$Mapping_region[i],x = df_epitopes$Annotated_region[i],fixed = TRUE) )),FUN.VALUE = c(FALSE) ))
df_epitopes$Group <- as.character(df_epitopes$Group)
df_epitopes$RFU <- as.numeric(df_epitopes$RFU)
df_epitopes <- subset(df_epitopes, RFU>=1000)
df_epitopes$protein_start <- unname(ceiling((df_epitopes$Genomic_start - v_start_orfs[as.character(df_epitopes$Mapping_region)] + 1)/3))
df_epitopes$protein_end <- unname(ceiling((df_epitopes$Genomic_End - v_start_orfs[as.character(df_epitopes$Mapping_region)] + 1)/3))
#save table
#write.table(x=df_epitopes,file = paste0(output_workspace,"Mapped_Epitopes.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)
df_variants_NCBI_SRA_amplicon <- readRDS(paste0(output_workspace,"df_variants_SRA_amplicon_second_wave.rds"))
df_variants_NCBI_SRA_amplicon <- subset(df_variants_NCBI_SRA_amplicon,ORF%in%c("orf1a","orf1b","S","E","M","N"))
df_variants_NCBI_SRA_amplicon$is_fixed <- ifelse(test = df_variants_NCBI_SRA_amplicon$VarFreq>0.75,yes = "Yes",no = "No")

df_variants_NCBI_SRA_amplicon$ORF <- vapply(X = df_variants_NCBI_SRA_amplicon$Position,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
df_variants_NCBI_SRA_amplicon$gene <- vapply(X = df_variants_NCBI_SRA_amplicon$Position,FUN = function(x) return(find_gene_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
#duplicate variants of orf3a if they occur also in orf3b or orf3c
df_subset_orf3b_orf3c <- subset(df_variants_NCBI_SRA_amplicon,subset=(Position>=v_start_orfs["ORF3a"])&(Position<=v_end_orfs["ORF3a"]))
print(paste0("Example positions:",head(df_variants_NCBI_SRA_amplicon$Position)))
if (nrow(df_subset_orf3b_orf3c)>0){
  if (sum((df_subset_orf3b_orf3c$Position>=v_start_orfs["ORF3b"])&(df_subset_orf3b_orf3c$Position<=v_end_orfs["ORF3b"]))>0){
    df_subset_orf3b_orf3c[which((df_subset_orf3b_orf3c$Position>=v_start_orfs["ORF3b"])&(df_subset_orf3b_orf3c$Position<=v_end_orfs["ORF3b"])),"ORF"] <- "ORF3b"
    df_subset_orf3b_orf3c[which((df_subset_orf3b_orf3c$Position>=v_start_orfs["ORF3b"])&(df_subset_orf3b_orf3c$Position<=v_end_orfs["ORF3b"])),"gene"] <- "ORF3b"
  }
  if (sum((df_subset_orf3b_orf3c$Position>=v_start_orfs["ORF3c"])&(df_subset_orf3b_orf3c$Position<=v_end_orfs["ORF3c"]))>0){
    df_subset_orf3b_orf3c[which((df_subset_orf3b_orf3c$Position>=v_start_orfs["ORF3c"])&(df_subset_orf3b_orf3c$Position<=v_end_orfs["ORF3c"])),"ORF"] <- "ORF3c"
    df_subset_orf3b_orf3c[which((df_subset_orf3b_orf3c$Position>=v_start_orfs["ORF3c"])&(df_subset_orf3b_orf3c$Position<=v_end_orfs["ORF3c"])),"gene"] <- "ORF3c"
  }
  if (nrow(df_subset_orf3b_orf3c)>0){
    df_subset_orf3b_orf3c <- subset(df_subset_orf3b_orf3c,ORF!="ORF3a")
  }
  df_variants_NCBI_SRA_amplicon <- rbind(df_variants_NCBI_SRA_amplicon,df_subset_orf3b_orf3c)
}
#duplicate variants of ORF7a if they occur also in ORF7b
df_subset_orf7b <- subset(df_variants_NCBI_SRA_amplicon,subset=(Position>=v_start_orfs["ORF7a"])&(Position<=v_end_orfs["ORF7a"]))
if (nrow(df_subset_orf7b)>0){
  if (sum((df_subset_orf7b$Position>=v_start_orfs["ORF7b"])&(df_subset_orf7b$Position<=v_end_orfs["ORF7b"]))>0){
    df_subset_orf7b[which((df_subset_orf7b$Position>=v_start_orfs["ORF7b"])&(df_subset_orf7b$Position<=v_end_orfs["ORF7b"])),"ORF"] <- "ORF7b"
  }
  if (nrow(df_subset_orf7b)>0){
    df_subset_orf7b <- subset(df_subset_orf7b,ORF!="ORF7a")
  }
  df_variants_NCBI_SRA_amplicon <- rbind(df_variants_NCBI_SRA_amplicon,df_subset_orf7b)
}
#duplicate variants of N if they occur also in orf9c
df_subset_ORF9c <- subset(df_variants_NCBI_SRA_amplicon,subset=(Position>=v_start_orfs["N"])&(Position<=v_end_orfs["N"]))
if (nrow(df_subset_ORF9c)>0){
  if (sum((df_subset_ORF9c$Position>=v_start_orfs["ORF9c"])&(df_subset_ORF9c$Position<=v_end_orfs["ORF9c"]))>0){
    df_subset_ORF9c[which((df_subset_ORF9c$Position>=v_start_orfs["ORF9c"])&(df_subset_ORF9c$Position<=v_end_orfs["ORF9c"])),"ORF"] <- "ORF9c"
  }
  if (nrow(df_subset_ORF9c)>0){
    df_subset_ORF9c <- subset(df_subset_ORF9c,ORF!="N")
  }
  df_variants_NCBI_SRA_amplicon <- rbind(df_variants_NCBI_SRA_amplicon,df_subset_ORF9c)
}

#function that find the original and mutated codons of a variant
get_ref_and_mutated_codon <- function(the_position,ref_nucl,new_nucl){
  the_orf <- find_ORF_of_mutation(the_position)
  if (is.na(the_orf)||(grepl(pattern = "UTR",x = the_orf,fixed = TRUE))){
    the_ref_codon <- NA
    the_mut_codon <- NA
  }else{
    pos_in_codon <- ((the_position - v_start_orfs[the_orf] + 1)%%3)+(3*as.integer(((the_position - v_start_orfs[the_orf] + 1)%%3)==0))
    if (pos_in_codon==1){
      the_ref_codon <- paste0(ref_nucl,substr(x = genome_refseq,start = the_position+1,stop = the_position+2),sep="")
      the_mut_codon <- paste0(new_nucl,substr(x = genome_refseq,start = the_position+1,stop = the_position+2),sep="")
    }else if (pos_in_codon==2){
      the_ref_codon <- paste0(substr(x = genome_refseq,start = the_position-1,stop = the_position-1),ref_nucl,substr(x = genome_refseq,start = the_position+1,stop = the_position+1),sep="")
      the_mut_codon <- paste0(substr(x = genome_refseq,start = the_position-1,stop = the_position-1),new_nucl,substr(x = genome_refseq,start = the_position+1,stop = the_position+1),sep="")
    }else if (pos_in_codon==3){
      the_ref_codon <- paste0(substr(x = genome_refseq,start = the_position-2,stop = the_position-1),ref_nucl,sep="")
      the_mut_codon <- paste0(substr(x = genome_refseq,start = the_position-2,stop = the_position-1),new_nucl,sep="")
    }else{
      stop("Codon position must be between 1 and 3!!!")
    }
  }
  return(list(ref_codon=the_ref_codon,mutated_codon=the_mut_codon))
}
#build function that determines whether a mutation is synonymous or not
is_mutation_synonymous <- function(the_reference_codon,the_mutated_codon){
  if (the_reference_codon %in% c("TAA","TAG","TGA")){
    return(NA)
  }else{
    return(seqinr::translate(seq = unlist(strsplit(the_reference_codon,"")))==seqinr::translate(seq = unlist(strsplit(the_mutated_codon,""))))
  }
}
#build function that determines whether a mutation is synonymous or not
translate_seq <- function(the_codon){
  if (is.na(the_codon)){
    return(NA)
  }else if (the_codon %in% c("TAA","TAG","TGA")){
    return("Stop")
  }else{
    return(seqinr::translate(seq = unlist(strsplit(the_codon,""))))
  }
}
#Original codon and mutated codon
df_variants_NCBI_SRA_amplicon$ref_codon <- NA
df_variants_NCBI_SRA_amplicon$mut_codon <- NA
df_variants_NCBI_SRA_amplicon$pos_in_ORF <- NA
df_variants_NCBI_SRA_amplicon$pos_in_gene <- NA
df_variants_NCBI_SRA_amplicon$pos_in_protein <- NA
for (i in 1:nrow(df_variants_NCBI_SRA_amplicon)){
  df_variants_NCBI_SRA_amplicon$ref_codon[i] <-(get_ref_and_mutated_codon(the_position = df_variants_NCBI_SRA_amplicon$Position[i],ref_nucl = df_variants_NCBI_SRA_amplicon$Ref[i],new_nucl = df_variants_NCBI_SRA_amplicon$VarAllele[i]))$ref_codon
  df_variants_NCBI_SRA_amplicon$mut_codon[i] <-(get_ref_and_mutated_codon(the_position = df_variants_NCBI_SRA_amplicon$Position[i],ref_nucl = df_variants_NCBI_SRA_amplicon$Ref[i],new_nucl = df_variants_NCBI_SRA_amplicon$VarAllele[i]))$mutated_codon
  df_variants_NCBI_SRA_amplicon$old_aa[i] <- translate_seq(the_codon = df_variants_NCBI_SRA_amplicon$ref_codon[i])
  df_variants_NCBI_SRA_amplicon$new_aa[i] <- translate_seq(the_codon = df_variants_NCBI_SRA_amplicon$mut_codon[i] )
  df_variants_NCBI_SRA_amplicon$pos_in_ORF[i] <- df_variants_NCBI_SRA_amplicon$Position[i] - v_start_orfs[df_variants_NCBI_SRA_amplicon$ORF[i]] + 1
  df_variants_NCBI_SRA_amplicon$pos_in_gene[i] <- df_variants_NCBI_SRA_amplicon$Position[i] - v_start_genes[df_variants_NCBI_SRA_amplicon$gene[i]] + 1
  df_variants_NCBI_SRA_amplicon$pos_in_protein[i] <- ceiling(df_variants_NCBI_SRA_amplicon$pos_in_gene[i]/3)
  #print(paste0("Iterations ",i," out of ",nrow(df_variants_NCBI_SRA_amplicon)))
}
df_variants_NCBI_SRA_amplicon$mutation_name <- paste0(paste0(df_variants_NCBI_SRA_amplicon$Ref,df_variants_NCBI_SRA_amplicon$Position,df_variants_NCBI_SRA_amplicon$VarAllele,""),";",paste0(df_variants_NCBI_SRA_amplicon$old_aa,df_variants_NCBI_SRA_amplicon$pos_in_protein,df_variants_NCBI_SRA_amplicon$new_aa),";",df_variants_NCBI_SRA_amplicon$ORF,";",df_variants_NCBI_SRA_amplicon$gene)
#Define Nonsense and non-coding mutations
df_variants_NCBI_SRA_amplicon$is_nonsense <- (df_variants_NCBI_SRA_amplicon$new_aa=="Stop")
df_variants_NCBI_SRA_amplicon$is_UTR <- (is.na(df_variants_NCBI_SRA_amplicon$new_aa))
df_variants_NCBI_SRA_amplicon$is_synonymous <- ifelse((is.na(df_variants_NCBI_SRA_amplicon$old_aa)|(df_variants_NCBI_SRA_amplicon$new_aa=="Stop")),yes = NA,no = df_variants_NCBI_SRA_amplicon$old_aa==df_variants_NCBI_SRA_amplicon$new_aa)

df_variants_NCBI_SRA_amplicon$mutation_type <- ifelse(test = df_variants_NCBI_SRA_amplicon$is_UTR,yes = "UTR",no = ifelse(test = df_variants_NCBI_SRA_amplicon$is_nonsense,yes = "Nonsense",no = ifelse(test = df_variants_NCBI_SRA_amplicon$is_synonymous,yes = "Synonymous",no = "Non-Synonymous")))
df_variants_NCBI_SRA_amplicon$S_protein_domain <- ifelse(test=df_variants_NCBI_SRA_amplicon$ORF=="S",yes = vapply(X = df_variants_NCBI_SRA_amplicon$pos_in_protein,FUN = function(x) return(find_S_protein_domain_of_mutation(the_site_position = x)),FUN.VALUE = c("")),no=NA)
v_recurrence_mut_NCBI_SRA_amplicon <- as.vector(table(df_variants_NCBI_SRA_amplicon$mutation_name))
names(v_recurrence_mut_NCBI_SRA_amplicon) <- names(table(df_variants_NCBI_SRA_amplicon$mutation_name))
df_variants_NCBI_SRA_amplicon$is_prevalence_above_transmission_threshold <- df_variants_NCBI_SRA_amplicon$mutation_name%in%(names(v_recurrence_mut_NCBI_SRA_amplicon)[v_recurrence_mut_NCBI_SRA_amplicon>=3])
v_nb_samples_NCBI_SRA_amplicon <- length(unique(df_variants_NCBI_SRA_amplicon$Sample))
#name of the reference genome fasta file
fasta_refseq_filename <- "MN908947_3.fasta"
#import reference fasta
genome_refseq <- seqinr::getSequence(object = toupper(read.fasta(paste0(output_workspace,fasta_refseq_filename),seqtype = "DNA",as.string = TRUE,forceDNAtolower = FALSE)),as.string = TRUE)[[1]]

#Presence of mutations of interest in the S protein (define by Emma B. Hodcroft as of 2020-12-23 and https://virological.org/t/mutations-arising-in-sars-cov-2-spike-on-sustained-human-to-human-transmission-and-human-to-animal-passage/578)
v_S_region_mutations_of_interest <- sort(unique(c("A222V","S477N","S98F","D80Y","N439K","Y453F","N501S","N501T","N501Y","A626S","V1122L","H69","D80A", "D215G", "P681H", "A701V", "T716I", "D1118H", "D614G","A570D", "K417N", "E484K", "N501Y", "S983A")))

#peptide per group
v_peptide_group1 <- subset(df_epitopes,Group==1)$Peptide
v_peptide_group2 <- subset(df_epitopes,Group==2)$Peptide
v_peptide_group3 <- subset(df_epitopes,Group==3)$Peptide
v_position_peptide_group1 <- NULL
for (i in 1:nrow(subset(df_epitopes,Group==1))){
  v_position_peptide_group1 <- c(v_position_peptide_group1, ((subset(df_epitopes,Group==1)$Genomic_start[i]):(subset(df_epitopes,Group==1)$Genomic_End[i])))
}
v_position_peptide_group1 <- sort(v_position_peptide_group1)
v_position_peptide_group2 <- NULL
for (i in 1:nrow(subset(df_epitopes,Group==2))){
  v_position_peptide_group2 <- c(v_position_peptide_group2, ((subset(df_epitopes,Group==2)$Genomic_start[i]):(subset(df_epitopes,Group==2)$Genomic_End[i])))
}
v_position_peptide_group2 <- sort(v_position_peptide_group2)
v_position_peptide_group3 <- NULL
for (i in 1:nrow(subset(df_epitopes,Group==3))){
  v_position_peptide_group3 <- c(v_position_peptide_group3, ((subset(df_epitopes,Group==3)$Genomic_start[i]):(subset(df_epitopes,Group==3)$Genomic_End[i])))
}
v_position_peptide_group3 <- sort(v_position_peptide_group3)
v_position_with_highest_antibody_response <- NULL
for (i in 1:nrow(subset(df_epitopes,RFU>=quantile(df_epitopes$RFU,probs = 0.5)))){
  v_position_with_highest_antibody_response <- c(v_position_with_highest_antibody_response, subset(df_epitopes,RFU>=quantile(df_epitopes$RFU,probs = 0.5))$Genomic_start[i]:subset(df_epitopes,RFU>=quantile(df_epitopes$RFU,probs = 0.5))$Genomic_End[i])
}
v_position_with_highest_antibody_response <- sort(v_position_with_highest_antibody_response)
palette_patient_groups <- c("1"=alpha("tomato",0.6), "2"=alpha('green3',0.6), "3"=alpha('royalblue',0.6))

#Venn Diagram
venn.diagram(
  x = list(v_peptide_group1,v_peptide_group2,v_peptide_group3),
  category.names = c("Group 1" , "Group 2","Group 3") ,
  filename =  paste0(output_workspace,"Venn_diagram_epitopes_peptides.png"),
  output = TRUE ,
  imagetype="png" ,
  fill = c(alpha("tomato",0.6), alpha('green3',0.6), alpha('deepskyblue',0.6)),
  height = 480 ,
  width = 480 ,
  resolution = 300,
  compression = "lzw",

  # Circles
  lwd = 2,
  lty = 'blank',

  # Numbers
  cex = .3,
  fontface = "bold",
  fontfamily = "sans",

  # Set names
  cat.cex = 0.3,
  cat.fontface = "bold",
  cat.default.pos = "outer",
  cat.pos = c(-27, 27, 135),
  cat.dist = c(0.055, 0.055, 0.085),
  cat.fontfamily = "sans",
  rotation = 1
)

#Represent epitopes on genome
df_position_epitopes_by_group <- rbind(data.frame(Group=1,Position=v_position_peptide_group1,stringsAsFactors = FALSE),data.frame(Group=2,Position=v_position_peptide_group2,stringsAsFactors = FALSE),data.frame(Group=3,Position=v_position_peptide_group3,stringsAsFactors = FALSE))
df_nb_occurence_epitope_position_by_group <- as.data.frame(table(df_position_epitopes_by_group$Group,df_position_epitopes_by_group$Position),stringAsFactors=FALSE)
names(df_nb_occurence_epitope_position_by_group) <- c("Group","Position","Count")
df_nb_occurence_epitope_position_by_group$Position <- as.integer(as.character(df_nb_occurence_epitope_position_by_group$Position))
df_nb_occurence_epitope_position_by_group$Group <- as.character(df_nb_occurence_epitope_position_by_group$Group)
##ggplot(df_nb_occurence_epitope_position_by_group) + geom_col(mapping = aes(x = Position,y=Count,fill=Group,Position="stack"))+theme_bw() + ylab("Count") + xlab("Genomic position (bp)") + scale_x_continuous(breaks = seq(0,30000,1500))  + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12))
##ggplot(data=df_nb_occurence_epitope_position_by_group,mapping=aes(x = Position)) + geom_area(aes(y=Count,fill=Group))+theme_bw() + ylab("Count") + xlab("Genomic position (bp)") + scale_x_continuous(breaks = seq(0,30000,1500))  + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12))
##ggsave(filename = "Mapped_epitopes_positions_split_by_group.png", path=output_workspace, width = 20, height = 12, units = "cm",dpi = 1200)
#p <- ggscatter(data = df_nb_occurence_epitope_position_by_group, x = "Position", y="Count",color = "Group",ggtheme = theme_light())+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("Number of occurences of a mapped peptide") + xlab("Genomic region")+ scale_x_continuous(breaks = seq(0,30000,1500),limits = c(0,30000))
#facet(p, facet.by = "Group", ncol = 1)
##ggsave(filename = "Mapped_epitopes_positions_split_by_group.png", path=output_workspace, width = 20, height = 20, units = "cm",dpi = 1200)
##ggsave(filename = "Mapped_epitopes_positions_split_by_group.eps", path=output_workspace, width = 20, height = 12, units = "cm",dpi = 1200,device = cairo_ps)

#RFU across ORFs and groups
#p <- #ggboxplot(data = df_epitopes, x = "Mapping_region", y="RFU",color = "Group",add = "jitter")+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Genomic region") +scale_y_continuous(limits = c(0,max(df_epitopes$RFU)+10000),breaks=seq(0,max(df_epitopes$RFU)+10000,10000))
#facet(p +  stat_compare_means(), facet.by = "Group", ncol = 1)
##ggsave(filename = "RFU_by_ORF_and_Groups.png", path=output_workspace, width = 20, height = 20, units = "cm",dpi = 1200)

#RFU across groups
##ggboxplot(data = df_epitopes, x = "Group", y="RFU",color = "Group",add = "jitter") +  stat_compare_means() + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Group")
##ggsave(filename = "RFU_by_Groups.png", path=output_workspace, width = 20, height = 15, units = "cm",dpi = 1200)

#RFU across Antibody and groups
#p <- #ggboxplot(data = df_epitopes, x = "Antibody", y="RFU",color = "Group",add = "jitter")+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Antibody") +scale_y_continuous(limits = c(0,max(df_epitopes$RFU)+10000),breaks=seq(0,max(df_epitopes$RFU)+10000,10000))
#facet(p +  stat_compare_means(), facet.by = "Group", ncol = 1)
##ggsave(filename = "RFU_by_Antibody_and_Groups.png", path=output_workspace, width = 20, height = 20, units = "cm",dpi = 1200)

df_regions_per_group <- as.data.frame(table(df_epitopes$Mapping_region,df_epitopes$Group),stringAsFactors=FALSE)
names(df_regions_per_group) <- c("Mapped_region","Group","Count")
df_regions_per_group$Group <- paste0("Group",as.integer(df_regions_per_group$Group))
df_regions_per_group$Mapped_region <- factor(df_regions_per_group$Mapped_region,intersect(v_orfs,df_regions_per_group$Mapped_region))

#p <- #ggbarplot(data = df_regions_per_group, x = "Mapped_region", y="Count", fill="Group",ggtheme = theme_light())+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("Number of epitope occurrences") + xlab("Genomic region")
#facet(p, facet.by = "Group", ncol = 1)
##ggsave(filename = "Number_of_mapped_epitope_peptides_per_genomic_region.png", path=output_workspace, width = 15, height = 18, units = "cm",dpi = 1200)

df_regions_per_group$Density <- df_regions_per_group$Count/v_orfs_length[df_regions_per_group$Mapped_region]
#p <- #ggbarplot(data = df_regions_per_group, x = "Mapped_region", y="Density", fill="Group",ggtheme = theme_light())+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("Density of mapped peptides (count/ORF length)") + xlab("Genomic region")
#facet(p, facet.by = "Group", ncol = 1)
##ggsave(filename = "Density_of_mapped_epitope_peptides_per_genomic_region.png", path=output_workspace, width = 20, height = 15, units = "cm",dpi = 1200)

#top 100 epitope hotspots
df_epitopes_top100_hotspots <- (unique(df_nb_occurence_epitope_position_by_group[,c("Position","Count")])[order(unique(df_nb_occurence_epitope_position_by_group[,c("Position","Count")])$Count,decreasing = TRUE),])[1:100,]

#function for plotting linear model
ggplotRegression <- function (fit,ggsave_path,the_filename,xlabl=NA,ylabl=NA) {
  library(ggplot2)
  bool_gg_save <- TRUE
  if(is.na(xlabl)){
    xlabl <- names(fit$model)[2]
  }
  if(is.na(ylabl)){
    ylabl <- names(fit$model)[1]
  }
  adj_r_sq <- formatC(summary(fit)$adj.r.squared, format = "e", digits = 3)
  slope <-formatC(summary(fit)$coefficients[,1][2], format = "e", digits = 3)
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = formatC(unname(summary(fit)$coefficients[,3][2]), format = "e", digits = 3)),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = formatC(unname(summary(fit)$coefficients[,4][2]), format = "e", digits = 3)))
  tryCatch(expr = {ggplot(fit$model, aes_string(x = names(fit$model)[2], y = names(fit$model)[1])) +
      geom_point() +
      stat_smooth(method = "lm", col = "red") +
      xlab(xlabl)+
      ylab(ylabl)+
      labs(title = paste("Adj R2 = ",adj_r_sq,
                         " Slope =",slope,
                         " P =",p_val))+ theme(plot.title=element_text(hjust=0,size=12))},error=function(e) bool_gg_save <- FALSE)

  if (bool_gg_save){
    ggsave(filename = the_filename, path=ggsave_path, width = 15, height = 10, units = "cm")
  }else{
    print(paste0(the_filename, "won't be created because of it is irrelevant for gene in path ", ggsave_path))
  }
  #return result as the real float numbers
  adj_r_sq <- unname(summary(fit)$adj.r.squared)
  slope <-unname(summary(fit)$coefficients[,1][2])
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = unname(summary(fit)$coefficients[,3][2])),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = unname(summary(fit)$coefficients[,4][2])))
  return(list(adj_r_sq_current_lm = adj_r_sq,slope_current_lm = slope,p_val_current_lm=p_val))
}
ggplotRegression_export_eps <- function (fit,ggsave_path,the_filename,xlabl=NA,ylabl=NA) {
  library(ggplot2)
  bool_gg_save <- TRUE
  if(is.na(xlabl)){
    xlabl <- names(fit$model)[2]
  }
  if(is.na(ylabl)){
    ylabl <- names(fit$model)[1]
  }
  adj_r_sq <- formatC(summary(fit)$adj.r.squared, format = "e", digits = 3)
  slope <-formatC(summary(fit)$coefficients[,1][2], format = "e", digits = 3)
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = formatC(unname(summary(fit)$coefficients[,3][2]), format = "e", digits = 3)),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = formatC(unname(summary(fit)$coefficients[,4][2]), format = "e", digits = 3)))
  tryCatch(expr = {ggplot(fit$model, aes_string(x = names(fit$model)[2], y = names(fit$model)[1])) +
      geom_point() +
      stat_smooth(method = "lm", col = "red") +
      xlab(xlabl)+
      ylab(ylabl)+
      labs(title = paste("Adj R2 = ",adj_r_sq,
                         " Slope =",slope,
                         " P =",p_val))+ theme(plot.title=element_text(hjust=0,size=12))},error=function(e) bool_gg_save <- FALSE)

  if (bool_gg_save){
    ggsave(filename = the_filename, path=ggsave_path, width = 15, height = 10, units = "cm", device = cairo_ps)
  }else{
    print(paste0(the_filename, "won't be created because of it is irrelevant for gene in path ", ggsave_path))
  }
  #return result as the real float numbers
  adj_r_sq <- unname(summary(fit)$adj.r.squared)
  slope <-unname(summary(fit)$coefficients[,1][2])
  p_val <- ifelse(test = "Iter"%in%colnames(summary(fit)$coefficients),yes=ifelse(test = unname(summary(fit)$coefficients[,3][2])<(2E-4),yes = "<2E-4",no = unname(summary(fit)$coefficients[,3][2])),no=ifelse(test = unname(summary(fit)$coefficients[,4][2])<(2e-16),yes = "<2e-16",no = unname(summary(fit)$coefficients[,4][2])))
  return(list(adj_r_sq_current_lm = adj_r_sq,slope_current_lm = slope,p_val_current_lm=p_val))
}
#build function that determines whether a mutation is synonymous or not
is_mutation_synonymous <- function(the_reference_codon,the_mutated_codon){
  if (the_reference_codon %in% c("TAA","TAG","TGA")){
    return(NA)
  }else{
    return(translate(seq = unlist(strsplit(the_reference_codon,"")))==translate(seq = unlist(strsplit(the_mutated_codon,""))))
  }
}
#build function that determines whether a mutation is synonymous or not
translate_seq <- function(the_codon){
  if (is.na(the_codon)){
    return(NA)
  }else if (the_codon %in% c("TAA","TAG","TGA")){
    return("Stop")
  }else{
    return(translate(seq = unlist(strsplit(the_codon,""))))
  }
}
# #function that determines if a mutation is in a mutation hotspot, as identified on nextrain April 24, 2020
# is_in_mutation_hotspot <- function(the_variant){
#   return(any(sapply(X = c(4049:4051,11081:11083,13400:13402,14407:14409,21575:21577),FUN = function(x) return(grepl(pattern = as.character(x),x = the_variant,fixed = TRUE)))))
# }
# #Vectorial version of the function "is_in_mutation_hotspot"
# is_in_mutation_hotspot_vec <- function(x){
#   return(vapply(X = x,FUN = function(y) return(is_in_mutation_hotspot(y)),FUN.VALUE = c(FALSE)))
# }

#create a function that returns number of synonymous sites for a single position in the genome
calculate_nb_ss_position_in_genome <- function(the_position){
  the_orf <- find_ORF_of_mutation(the_position)
  if (is.na(the_orf)||(grepl(pattern = "UTR",x = the_orf,fixed = TRUE))){
    return(NA)
  }else{
    pos_in_codon <- ((the_position - v_start_orfs[the_orf] + 1)%%3)+(3*as.integer(((the_position - v_start_orfs[the_orf] + 1)%%3)==0))
    if (pos_in_codon==1){
      the_codon <- substr(x = genome_refseq,start = the_position,stop = the_position+2)
    }else if (pos_in_codon==2){
      the_codon <- substr(x = genome_refseq,start = the_position-1,stop = the_position+1)
    }else if (pos_in_codon==3){
      the_codon <- substr(x = genome_refseq,start = the_position-2,stop = the_position)
    }else{
      stop("Codon position must be between 1 and 3!!!")
    }
  }
  if (nchar(the_codon)!=3){
    stop("codon length should be 3!")
  }
  possible_single_site_mutated_codons <- rep("",3)
  num_mut_codon <-1
  for (pos_codon in pos_in_codon){
    if (substr(the_codon,start = pos_codon,stop=pos_codon)=="A"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1

    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="T"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="C"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else{#G
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }
  }
  #count the number of synonymous mutations based on the genetic code
  nb_unique_syn_mut_codons <-0 #default initialization
  if (the_codon == "TTT") {
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTC"])

  } else if (the_codon == "TTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTT"])

  } else if (the_codon == "TTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTG","CTT","CTC","CTA","CTG")])

  } else if (the_codon == "TTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","CTT","CTC","CTA","CTG")])

  } else if (the_codon == "TCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCC","TCA","TCG","AGT","AGC")])
  } else if (the_codon == "TCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCG","AGT","AGC")])

  } else if (the_codon == "TCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCC","TCG","AGT","AGC")])

  } else if (the_codon == "TCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCC","AGT","AGC")])

  } else if (the_codon == "TAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAC")])

  } else if (the_codon == "TAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAT")])

  } else if (the_codon == "TGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGC")])

  } else if (the_codon == "TGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGT")])

  } else if (the_codon == "TGG"){
    nb_unique_syn_mut_codons <- 0

  } else if (the_codon == "CTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTC","CTA","CTG")])

  } else if (the_codon == "CTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTA","CTG")])

  } else if (the_codon == "CTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTG")])

  } else if (the_codon == "CTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTA")])

  } else if (the_codon == "CCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCC","CCA","CCG")])

  } else if (the_codon == "CCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCA","CCG")])


  } else if (the_codon == "CCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCG")])

  } else if (the_codon == "CCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCA")])

  } else if (the_codon == "CAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAC")])

  } else if (the_codon == "CAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAT")])

  } else if (the_codon == "CAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAG")])

  } else if (the_codon == "CAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAA")])

  } else if (the_codon == "CGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGC","CGA","CGG")])

  } else if (the_codon == "CGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGG")])

  } else if (the_codon == "CGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGC","CGG")])

  } else if (the_codon == "CGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGC")])

  } else if (the_codon == "ATT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATA")])

  } else if (the_codon == "ATC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATT","ATA")])

  } else if (the_codon == "ATA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATT")])

  } else if (the_codon == "ATG"){
    nb_unique_syn_mut_codons <- 0

  } else if (the_codon == "ACT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACC","ACA","ACG")])


  } else if (the_codon == "ACC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACA","ACG")])

  } else if (the_codon == "ACA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACG")])


  } else if (the_codon == "ACG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACA")])

  } else if (the_codon == "AAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAC")])

  } else if (the_codon == "AAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAT")])

  } else if (the_codon == "AAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAG")])

  } else if (the_codon == "AAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAA")])

  } else if (the_codon == "AGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGC","TCT","TCC","TCA","TCG")])

  } else if (the_codon == "AGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGT","TCT","TCC","TCA","TCG")])

  } else if (the_codon == "AGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGG")])

  } else if (the_codon == "AGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGA")])

  } else if (the_codon == "GTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTG")])

  } else if (the_codon == "GTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTT","GTA","GTG")])

  } else if (the_codon == "GTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTT","GTG")])

  } else if (the_codon == "GTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTT")])

  } else if (the_codon == "GCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCG")])

  } else if (the_codon == "GCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCT","GCA","GCG")])

  } else if (the_codon == "GCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCT","GCG")])

  } else if (the_codon == "GCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCT")])

  } else if (the_codon == "GAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAC")])

  } else if (the_codon == "GAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAT")])

  } else if (the_codon == "GAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAG")])

  } else if (the_codon == "GAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAA")])

  } else if (the_codon == "GGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGG")])

  } else if (the_codon == "GGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGT","GGA","GGG")])

  } else if (the_codon == "GGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGT","GGG")])


  } else if (the_codon == "GGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGT")])
  }
  return((nb_unique_syn_mut_codons/3))
}

#create a function that returns number of possible SINGLE-SITE synonymous mutations divided by 3 for a CODON
calculate_third_of_possible_ns_codon <- function(the_codon){
  the_codon <- toupper(the_codon)
  if (nchar(the_codon)!=3){
    stop("codon length should be 3!")
  }
  possible_single_site_mutated_codons <- rep("",9)
  num_mut_codon <-1
  for (pos_codon in 1:3){
    if (substr(the_codon,start = pos_codon,stop=pos_codon)=="A"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1

    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="T"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else if (substr(the_codon,start = pos_codon,stop=pos_codon)=="C"){
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "G"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }else{#G
      mut_codon_1 <- the_codon
      substr(mut_codon_1,start = pos_codon,stop=pos_codon) <- "A"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_1
      num_mut_codon=num_mut_codon+1
      mut_codon_2 <- the_codon
      substr(mut_codon_2,start = pos_codon,stop=pos_codon) <- "T"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_2
      num_mut_codon=num_mut_codon+1
      mut_codon_3 <- the_codon
      substr(mut_codon_3,start = pos_codon,stop=pos_codon) <- "C"
      possible_single_site_mutated_codons[num_mut_codon] <- mut_codon_3
      num_mut_codon=num_mut_codon+1
    }
  }
  #count the number of synonymous mutations based on the genetic code
  nb_unique_syn_mut_codons <-0 #default initialization
  if (the_codon == "TTT") {
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTC"])

  } else if (the_codon == "TTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons=="TTT"])

  } else if (the_codon == "TTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTG","CTT","CTC","CTA","CTG")])

  } else if (the_codon == "TTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","CTT","CTC","CTA","CTG")])

  } else if (the_codon == "TCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCC","TCA","TCG","AGT","AGC")])
  } else if (the_codon == "TCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCG","AGT","AGC")])

  } else if (the_codon == "TCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCC","TCG","AGT","AGC")])

  } else if (the_codon == "TCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TCT","TCA","TCC","AGT","AGC")])

  } else if (the_codon == "TAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAC")])

  } else if (the_codon == "TAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TAT")])

  } else if (the_codon == "TGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGC")])

  } else if (the_codon == "TGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TGT")])

  } else if (the_codon == "TGG"){
    nb_unique_syn_mut_codons <- 0

  } else if (the_codon == "CTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTC","CTA","CTG")])

  } else if (the_codon == "CTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTA","CTG")])

  } else if (the_codon == "CTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTG")])

  } else if (the_codon == "CTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("TTA","TTG","CTT","CTC","CTA")])

  } else if (the_codon == "CCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCC","CCA","CCG")])

  } else if (the_codon == "CCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCA","CCG")])


  } else if (the_codon == "CCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCG")])

  } else if (the_codon == "CCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CCT","CCC","CCA")])

  } else if (the_codon == "CAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAC")])

  } else if (the_codon == "CAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAT")])

  } else if (the_codon == "CAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAG")])

  } else if (the_codon == "CAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CAA")])

  } else if (the_codon == "CGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGC","CGA","CGG")])

  } else if (the_codon == "CGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGG")])

  } else if (the_codon == "CGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGC","CGG")])

  } else if (the_codon == "CGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("CGT","CGA","CGC")])

  } else if (the_codon == "ATT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATA")])

  } else if (the_codon == "ATC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATT","ATA")])

  } else if (the_codon == "ATA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ATC","ATT")])

  } else if (the_codon == "ATG"){
    nb_unique_syn_mut_codons <- 0

  } else if (the_codon == "ACT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACC","ACA","ACG")])


  } else if (the_codon == "ACC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACA","ACG")])

  } else if (the_codon == "ACA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACG")])


  } else if (the_codon == "ACG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("ACT","ACC","ACA")])

  } else if (the_codon == "AAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAC")])

  } else if (the_codon == "AAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAT")])

  } else if (the_codon == "AAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAG")])

  } else if (the_codon == "AAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AAA")])

  } else if (the_codon == "AGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGC","TCT","TCC","TCA","TCG")])

  } else if (the_codon == "AGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGT","TCT","TCC","TCA","TCG")])

  } else if (the_codon == "AGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGG")])

  } else if (the_codon == "AGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("AGA")])

  } else if (the_codon == "GTT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTG")])

  } else if (the_codon == "GTC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTT","GTA","GTG")])

  } else if (the_codon == "GTA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTT","GTG")])

  } else if (the_codon == "GTG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GTC","GTA","GTT")])

  } else if (the_codon == "GCT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCG")])

  } else if (the_codon == "GCC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCT","GCA","GCG")])

  } else if (the_codon == "GCA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCT","GCG")])

  } else if (the_codon == "GCG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GCC","GCA","GCT")])

  } else if (the_codon == "GAT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAC")])

  } else if (the_codon == "GAC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAT")])

  } else if (the_codon == "GAA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAG")])

  } else if (the_codon == "GAG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GAA")])

  } else if (the_codon == "GGT"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGG")])

  } else if (the_codon == "GGC"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGT","GGA","GGG")])

  } else if (the_codon == "GGA"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGT","GGG")])


  } else if (the_codon == "GGG"){
    nb_unique_syn_mut_codons <- length(possible_single_site_mutated_codons[possible_single_site_mutated_codons %in% c("GGC","GGA","GGT")])
  }
  return((nb_unique_syn_mut_codons/3))
}

calculate_epitope_related_sites_nb_ss <- function(start_pos,end_pos){
  Nb_syn_sites_peptide <- 0
  for (pos_in_gene in seq(from =start_pos,to = end_pos,by = 3)){
    current_codon_gene <- substr(x = genome_refseq,start = pos_in_gene,stop=pos_in_gene+2)
    Nb_syn_sites_peptide <- Nb_syn_sites_peptide + calculate_third_of_possible_ns_codon(current_codon_gene)
  }
  return(Nb_syn_sites_peptide)
}

v_nb_ss_epitope_related_coding_regions <- NULL
for (i in 1:nrow(df_epitopes)){
  if (!paste0(df_epitopes$Genomic_start[i],"-",df_epitopes$Genomic_End[i])%in%names(v_nb_ss_epitope_related_coding_regions)){
    v_nb_ss_epitope_related_coding_regions <- c(v_nb_ss_epitope_related_coding_regions,calculate_epitope_related_sites_nb_ss(start_pos = df_epitopes$Genomic_start[i],end_pos = df_epitopes$Genomic_End[i]))
    names(v_nb_ss_epitope_related_coding_regions)[length(v_nb_ss_epitope_related_coding_regions)] <- paste0(df_epitopes$Genomic_start[i],"-",df_epitopes$Genomic_End[i])
  }
}

get_position_mutation <- function(the_mut_name){
  return(as.integer(substr(x = the_mut_name,start = 2,stop = as.vector(regexpr(pattern = ";",text = the_mut_name,fixed = T))-2)))
}

v_group_patient <- unique(df_epitopes[,c("patient_ID","Group")])$Group
names(v_group_patient) <- unique(df_epitopes[,c("patient_ID","Group")])$patient_ID

v_seq_peptide <- unique(df_epitopes[,c("peptide_id","Peptide")])$Peptide
names(v_seq_peptide) <- unique(df_epitopes[,c("peptide_id","Peptide")])$peptide_id

#known epitope sites
v_unique_epitope_positions <- sort(unique(c(v_position_peptide_group1,v_position_peptide_group2,v_position_peptide_group3)))
#Non-epitope sites in analyzed ORFs
v_non_epitope_sites <- sort(unique(setdiff(c(v_start_orfs["orf1a"]:v_end_orfs["orf1a"],v_start_orfs["orf1b"]:v_end_orfs["orf1b"],v_start_orfs["S"]:v_end_orfs["S"],v_start_orfs["E"]:v_end_orfs["E"],v_start_orfs["M"]:v_end_orfs["M"],v_start_orfs["N"]:v_end_orfs["N"]),v_unique_epitope_positions)))#sort(unique(setdiff(setdiff(1:nchar(genome_refseq),c(v_start_orfs["ORF3a"]:v_end_orfs["ORF3a"],v_start_orfs["ORF3b"]:v_end_orfs["ORF3b"],v_start_orfs["ORF3c"]:v_end_orfs["ORF3c"],v_start_orfs["ORF6"]:v_end_orfs["ORF6"],v_start_orfs["ORF7a"]:v_end_orfs["ORF7a"],v_start_orfs["ORF7b"]:v_end_orfs["ORF7b"],v_start_orfs["ORF8"]:v_end_orfs["ORF8"],v_start_orfs["ORF10"]:v_end_orfs["ORF10"])),v_unique_epitope_positions)))

v_length_epitope_sites_vs_others <- c(length(v_unique_epitope_positions),length(v_non_epitope_sites))
names(v_length_epitope_sites_vs_others) <- c("TRUE","FALSE")

v_length_top100_epitope_hotspots_vs_others <- c(100,length(v_unique_epitope_positions)-100)
names(v_length_top100_epitope_hotspots_vs_others) <- c("TRUE","FALSE")

##ggplot(data = df_epitopes[,c("Genomic_start","Mapping_region","RFU")]) + geom_line(mapping = aes(x=Genomic_start,y=RFU,col=Mapping_region)) + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Position")+ guides(col=guide_legend(title="Genomic Region"))
##ggsave(filename = "Epitopes_RFU_across_SARS_CoV_2_genome.png", path=output_workspace, width = 20, height = 12, units = "cm",dpi = 1200)

#define shared and group-specific epitopes
df_nb_unique_groups_for_epitope <- aggregate(df_epitopes$Group,by=list(peptide_id=df_epitopes$peptide_id,Mapping_region=df_epitopes$Mapping_region,Genomic_start=df_epitopes$Genomic_start,Genomic_End=df_epitopes$Genomic_End),FUN= function(x) length(unique(x)))
df_nb_unique_groups_for_epitope$is_exclusive_to_group1 <- (df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==1)$peptide_id)&(!df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==2)$peptide_id)&(!df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==3)$peptide_id)
df_nb_unique_groups_for_epitope$is_exclusive_to_group2 <- (df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==2)$peptide_id)&(!df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==1)$peptide_id)&(!df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==2)$peptide_id)
df_nb_unique_groups_for_epitope$is_exclusive_to_group3 <- (df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==3)$peptide_id)&(!df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==1)$peptide_id)&(!df_nb_unique_groups_for_epitope$peptide_id[i]%in%subset(df_epitopes,Group==3)$peptide_id)
v_shared_epitope_positions <- NULL
for (i in 1:nrow(subset(df_nb_unique_groups_for_epitope,x>1))){
  v_shared_epitope_positions <- c(v_shared_epitope_positions,((subset(df_nb_unique_groups_for_epitope,x>1)$Genomic_start[i]):(subset(df_nb_unique_groups_for_epitope,x>1)$Genomic_End[i])))
}
v_shared_epitope_positions <- sort(unique(v_shared_epitope_positions))
v_group_specific_epitope_positions <- sort(unique(setdiff(v_unique_epitope_positions,v_shared_epitope_positions)))
v_length_shared_vs_other_epitope_positions <- c(length(v_shared_epitope_positions),length(v_group_specific_epitope_positions))
names(v_length_shared_vs_other_epitope_positions) <- c("TRUE","FALSE")

v_length_shared_vs_group_specific_epitope_positions <- c(length(v_shared_epitope_positions),length(v_group_specific_epitope_positions))
names(v_length_shared_vs_group_specific_epitope_positions) <- c("Shared","Group-specific")
v_coverage_shared_vs_group_specific_epitopes_positions_NCBI_SRA_amplicon <- c("Shared"=mean(subset(df_variants_NCBI_SRA_amplicon,Position%in%v_shared_epitope_positions)$total_depth,na.rm=T),"Group-specific"=mean(subset(df_variants_NCBI_SRA_amplicon,Position%in%v_group_specific_epitope_positions)$total_depth,na.rm=T))

#NCBI dataset
df_variants_NCBI_SRA_amplicon$is_epitope_related <- df_variants_NCBI_SRA_amplicon$Position%in% sort(v_unique_epitope_positions)
df_variants_NCBI_SRA_amplicon$is_in_top100_epitope <- df_variants_NCBI_SRA_amplicon$Position %in% df_epitopes_top100_hotspots$Position
df_variants_NCBI_SRA_amplicon$is_exclusive_to_group1 <- (df_variants_NCBI_SRA_amplicon$Position%in%v_position_peptide_group1)&(!df_variants_NCBI_SRA_amplicon$Position%in%c(v_position_peptide_group2,v_position_peptide_group3))
df_variants_NCBI_SRA_amplicon$is_exclusive_to_group2 <- (df_variants_NCBI_SRA_amplicon$Position%in%v_position_peptide_group1)&(!df_variants_NCBI_SRA_amplicon$Position%in%c(v_position_peptide_group1,v_position_peptide_group3))
df_variants_NCBI_SRA_amplicon$is_exclusive_to_group3 <- (df_variants_NCBI_SRA_amplicon$Position%in%v_position_peptide_group1)&(!df_variants_NCBI_SRA_amplicon$Position%in%c(v_position_peptide_group1,v_position_peptide_group2))
df_variants_NCBI_SRA_amplicon$is_shared_epitope_position <- df_variants_NCBI_SRA_amplicon$Position%in%v_shared_epitope_positions
lst_samples_NCBI_SRA_amplicon <- sort(unique(df_variants_NCBI_SRA_amplicon$Sample))
#determine what's the minimum coverage required for a site to have at least 80% power for detecting at least 10 copies of SNVs at >=5%
min_cov <- 1
p <- 0
min_nb_reads_supporting_snv <- 5

while (p<0.8){
  p <- 1 - pbinom(q = min_nb_reads_supporting_snv, size = min_cov, prob = 0.05)
  min_cov <- min_cov + 1
  if (min_cov%% 10){
    print(paste0("current min cov :", min_cov))
  }
}

df_variants_site_enough_covered_NCBI_SRA_amplicon <- subset(df_variants_NCBI_SRA_amplicon, total_depth>=min_cov)
v_unique_epitope_positions_with_enough_coverage_NCBI_SRA_amplicon <- intersect(v_unique_epitope_positions,df_variants_site_enough_covered_NCBI_SRA_amplicon$Position)

v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon <- unique(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,mutation_type=="Non-Synonymous")$mutation_name)
v_lst_synonymous_mutations_NCBI_SRA_amplicon <- unique(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,mutation_type=="Synonymous")$mutation_name)

#Number of variants in epitopes per genomic region
df_unique_variants_per_region_NCBI_SRA_amplicon <- unique(data.frame(mutation_name=subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_epitope_related))$mutation_name,Genomic_region=subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_epitope_related))$ORF),stringAsFactors=FALSE)
v_nb_variants_per_region_NCBI_SRA_amplicon <- table(df_unique_variants_per_region_NCBI_SRA_amplicon$Genomic_region)
##ggbarplot(data = data.frame(x=intersect(names(v_start_orfs),names(v_nb_variants_per_region_NCBI_SRA_amplicon)),y=as.vector(v_nb_variants_per_region_NCBI_SRA_amplicon[intersect(names(v_start_orfs),names(v_nb_variants_per_region_NCBI_SRA_amplicon))]),stringsAsFactors = FALSE), x = "x", y="y", fill="black",ggtheme = theme_light())+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("Number of variants in epitope-related sites") + xlab("Genomic region")
##ggsave(filename = "Number_of_unique_variants_per_genomic_region_NCBI_SRA_amplicon.png", path=output_workspace, width = 20, height = 12, units = "cm",dpi = 1200)

#Number of fixed variants in epitopes per genomic region
df_unique_fixed_variants_per_region_NCBI_SRA_amplicon <- unique(data.frame(mutation_name=subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_epitope_related)&(is_fixed=="Yes"))$mutation_name,Genomic_region=subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_epitope_related)&(is_fixed=="Yes"))$ORF),stringAsFactors=FALSE)
v_nb_fixed_variants_per_region_NCBI_SRA_amplicon <- table(df_unique_fixed_variants_per_region_NCBI_SRA_amplicon$Genomic_region)
##ggbarplot(data = data.frame(x=intersect(names(v_start_orfs),names(v_nb_variants_per_region_NCBI_SRA_amplicon)),y=as.vector(v_nb_fixed_variants_per_region_NCBI_SRA_amplicon[intersect(names(v_start_orfs),names(v_nb_variants_per_region_NCBI_SRA_amplicon))]),stringsAsFactors = FALSE), x = "x", y="y", fill="black",ggtheme = theme_light())+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("Number of fixed variants in epitope-related sites") + xlab("Genomic region")
##ggsave(filename = "Number_of_fixed_variants_per_genomic_region_NCBI_SRA_amplicon.png", path=output_workspace, width = 20, height = 12, units = "cm",dpi = 1200)

#compare mutation and substitution rate in epitopes vs outside
df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon <- data.frame(Sample=rep(lst_samples_NCBI_SRA_amplicon,length(c(TRUE,FALSE))),is_epitope_related=rep(c(TRUE,FALSE),each=length(lst_samples_NCBI_SRA_amplicon)),nb_mutations=0,nb_fixed_mutations=0,mut_rate=0,subst_rate=0,stringsAsFactors = F)
nb_cores <- nb_cpus
lst_splits <- split(1:nrow(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon), ceiling(seq_along(1:nrow(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon))/(nrow(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon)/nb_cores)))
the_f_parallel_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon <- function(i_cl){
  the_vec<- lst_splits[[i_cl]]
  df_metrics_current_subset <- df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon[the_vec,]
  count_iter <- 0
  for (the_i in 1:nrow(df_metrics_current_subset)){
    df_depth_NCBI_SRA_amplicon_current_sample <- read.csv2(file = paste0(depth_data_wp,"depth_report_NCBI_SRA_amplicon/df_depth_NCBI_SRA_amplicon_",df_metrics_current_subset$Sample[the_i],".csv"),sep = ",",header = F,stringsAsFactors = FALSE)
    colnames(df_depth_NCBI_SRA_amplicon_current_sample) <- c("sample","position","depth")
    df_depth_NCBI_SRA_amplicon_current_sample$ORF <- vapply(X = df_depth_NCBI_SRA_amplicon_current_sample$position,FUN = find_ORF_of_mutation,FUN.VALUE = c(""))
    df_depth_NCBI_SRA_amplicon_current_sample <- unique(df_depth_NCBI_SRA_amplicon_current_sample)
    v_currentsample_positions_enough_covered <- subset(df_depth_NCBI_SRA_amplicon_current_sample,(depth>=min_cov))$position
    if (df_metrics_current_subset$is_epitope_related[the_i]){
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_unique_epitope_positions,v_currentsample_positions_enough_covered)
    }else{
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_non_epitope_sites,v_currentsample_positions_enough_covered)
    }
    df_metrics_current_subset$nb_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_fixed=="No")&(!Position%in%v_positions_inter)&(is_epitope_related==df_metrics_current_subset$is_epitope_related[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_fixed_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_fixed=="Yes")&(is_prevalence_above_transmission_threshold)&(is_epitope_related==df_metrics_current_subset$is_epitope_related[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] <- length(v_the_sites_with_enough_cov_for_current_category)
    df_metrics_current_subset$mut_rate[the_i] <- df_metrics_current_subset$nb_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$subst_rate[the_i] <- df_metrics_current_subset$nb_fixed_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$Nb_ss[the_i] <- sum(unname(vapply(X = v_the_sites_with_enough_cov_for_current_category,FUN = calculate_nb_ss_position_in_genome,FUN.VALUE = c(0))),na.rm=T)
    df_metrics_current_subset$Nb_nss[the_i] <- df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] - df_metrics_current_subset$Nb_ss[the_i]
    df_metrics_current_subset$within_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$within_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))

    if (the_i%%100==0){
      print(paste0("[Epitope sites vs others (NCBI)] Core ",i_cl,": Step ",the_i," done out of ",nrow(df_metrics_current_subset),"!"))
    }
  }
  df_metrics_current_subset$pN <- df_metrics_current_subset$within_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$pS <- df_metrics_current_subset$within_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$pN_pS <- ifelse(test=df_metrics_current_subset$pS==0,yes=NA,no=df_metrics_current_subset$pN/df_metrics_current_subset$pS)
  df_metrics_current_subset$dN <- df_metrics_current_subset$between_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$dS <- df_metrics_current_subset$between_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$dN_dS <- ifelse(test=df_metrics_current_subset$dS==0,yes=NA,no=df_metrics_current_subset$dN/df_metrics_current_subset$dS)
  df_metrics_current_subset$alpha_MK_Test <- ifelse(test=df_metrics_current_subset$dN_dS==0,yes=NA,no=(1-((df_metrics_current_subset$pN_pS)/(df_metrics_current_subset$dN_dS))))

  return(df_metrics_current_subset)
}
cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_Evo_rates_analyses.txt"))
registerDoParallel(cl)
df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel","Biostrings"))  %dopar% the_f_parallel_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon(i_cl)
stopCluster(cl)
saveRDS(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon,paste0(output_workspace,"df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon.rds"))

ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")),y = mut_rate,fill=as.character(is_epitope_related))) + geom_violin() + geom_point() + xlab("Epitope sites?") + ylab("Within-host mutation rate (Count / Length)") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$mut_rate)+1e-2,1e-2),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$mut_rate)+1e-2)) + stat_compare_means(method = "wilcox")
ggsave(filename = "Mutation_rate_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")),y = subst_rate,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("Epitope sites?") + ylab("Substitution rate (Count / Length)") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$subst_rate)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$subst_rate)+1e-4)) + stat_compare_means(method = "wilcox")
ggsave(filename = "Substitution_rate_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)

ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")),y = pN_pS,fill=as.character(is_epitope_related))) + geom_violin() + geom_point() + xlab("Epitope sites?") + ylab("pN/pS") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + stat_compare_means(method = "wilcox") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$pN_pS)+1e-2,1e-2),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$pN_pS)+1e-2))
ggsave(filename = "pN_pS_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")),y = dN_dS,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("Epitope sites?") + ylab("dN/dS") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + stat_compare_means(method = "wilcox") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$dN_dS)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$dN_dS)+1e-4))
ggsave(filename = "dN_dS_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")),y = alpha_MK_Test,fill=as.character(is_epitope_related))) + geom_violin() + geom_point() + xlab("Epitope sites?") + ylab("McDonald-Kreitman test \U003B1") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + stat_compare_means(method = "wilcox") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$alpha_MK_Test)+1e-2,1e-2),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon$alpha_MK_Test)+1e-2))
ggsave(filename = "MK_test_alpha_in_epitope_vs_out_of_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)

#compare mutation and substitution rate in epitopes vs outside (split by genomic region)
v_orfs_of_interest <- c("orf1a","orf1b","S","E","M","N")
df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon <- data.frame(Sample=rep(lst_samples_NCBI_SRA_amplicon,each=length(c(TRUE,FALSE))*length(v_orfs_of_interest)),is_epitope_related=rep(c(TRUE,FALSE),each=length(lst_samples_NCBI_SRA_amplicon)*length(v_orfs_of_interest)),ORF=rep(v_orfs_of_interest,length(lst_samples_NCBI_SRA_amplicon)*length(c(TRUE,FALSE))),nb_mutations=0,nb_fixed_mutations=0,mut_rate=0,subst_rate=0,stringsAsFactors = F)
nb_cores <- nb_cpus
lst_splits <- split(1:nrow(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon), ceiling(seq_along(1:nrow(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon))/(nrow(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon)/nb_cores)))
the_f_parallel_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon <- function(i_cl){
  the_vec<- lst_splits[[i_cl]]
  df_metrics_current_subset <- df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon[the_vec,]
  count_iter <- 0
  for (the_i in 1:nrow(df_metrics_current_subset)){
    df_depth_NCBI_SRA_amplicon_current_sample <- read.csv2(file = paste0(depth_data_wp,"depth_report_NCBI_SRA_amplicon/df_depth_NCBI_SRA_amplicon_",df_metrics_current_subset$Sample[the_i],".csv"),sep = ",",header = F,stringsAsFactors = FALSE)
    colnames(df_depth_NCBI_SRA_amplicon_current_sample) <- c("sample","position","depth")
    df_depth_NCBI_SRA_amplicon_current_sample$ORF <- vapply(X = df_depth_NCBI_SRA_amplicon_current_sample$position,FUN = find_ORF_of_mutation,FUN.VALUE = c(""))
    df_depth_NCBI_SRA_amplicon_current_sample <- unique(df_depth_NCBI_SRA_amplicon_current_sample)
    v_currentsample_positions_enough_covered <- subset(df_depth_NCBI_SRA_amplicon_current_sample,(depth>=min_cov)&(ORF==df_metrics_current_subset$ORF[the_i]))$position
    if (df_metrics_current_subset$is_epitope_related[the_i]){
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_unique_epitope_positions,v_currentsample_positions_enough_covered)
    }else{
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_non_epitope_sites,v_currentsample_positions_enough_covered)
    }
    df_metrics_current_subset$nb_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(ORF==df_metrics_current_subset$ORF[the_i])&(is_fixed=="No")&(!Position%in%v_positions_inter)&(is_epitope_related==df_metrics_current_subset$is_epitope_related[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_fixed_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(ORF==df_metrics_current_subset$ORF[the_i])&(is_fixed=="Yes")&(is_prevalence_above_transmission_threshold)&(is_epitope_related==df_metrics_current_subset$is_epitope_related[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] <- length(v_the_sites_with_enough_cov_for_current_category)
    df_metrics_current_subset$mut_rate[the_i] <- df_metrics_current_subset$nb_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$subst_rate[the_i] <- df_metrics_current_subset$nb_fixed_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$Nb_ss[the_i] <- sum(unname(vapply(X = v_the_sites_with_enough_cov_for_current_category,FUN = calculate_nb_ss_position_in_genome,FUN.VALUE = c(0))),na.rm=T)
    df_metrics_current_subset$Nb_nss[the_i] <- df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] - df_metrics_current_subset$Nb_ss[the_i]
    df_metrics_current_subset$within_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(ORF==df_metrics_current_subset$ORF[the_i])&(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$within_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(ORF==df_metrics_current_subset$ORF[the_i])&(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(ORF==df_metrics_current_subset$ORF[the_i])&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(ORF==df_metrics_current_subset$ORF[the_i])&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))

    if (the_i%%100==0){
      print(paste0("[Epitope sites vs others by ORF (NCBI)] Core ",i_cl,": Step ",the_i," done out of ",nrow(df_metrics_current_subset),"!"))
    }
  }
  df_metrics_current_subset$pN <- df_metrics_current_subset$within_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$pS <- df_metrics_current_subset$within_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$pN_pS <- ifelse(test=df_metrics_current_subset$pS==0,yes=NA,no=df_metrics_current_subset$pN/df_metrics_current_subset$pS)
  df_metrics_current_subset$dN <- df_metrics_current_subset$between_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$dS <- df_metrics_current_subset$between_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$dN_dS <- ifelse(test=df_metrics_current_subset$dS==0,yes=NA,no=df_metrics_current_subset$dN/df_metrics_current_subset$dS)
  df_metrics_current_subset$alpha_MK_Test <- ifelse(test=df_metrics_current_subset$dN_dS==0,yes=NA,no=(1-((df_metrics_current_subset$pN_pS)/(df_metrics_current_subset$dN_dS))))

  return(df_metrics_current_subset)
}
cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_Evo_rates_analyses.txt"))
registerDoParallel(cl)
df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel","Biostrings"))  %dopar% the_f_parallel_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon(i_cl)
stopCluster(cl)
saveRDS(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,paste0(output_workspace,"df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.rds"))
df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$label <- ifelse(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$is_epitope_related,yes="Epitope sites",no="Other sites")
#within-host mutation rate by ORF (NCBI_SRA_amplicon)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = mut_rate,fill=as.character(is_epitope_related))) + geom_violin() + geom_point() + xlab("ORF") + ylab("Within-host mutation rate (Count / Length)") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$mut_rate)+1e-2,1e-2),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$mut_rate)+1e-2)) + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1)
ggsave(filename = "Mutation_rate_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$mut_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$mut_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$mut_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$mut_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$mut_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$mut_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$mut_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$mut_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$mut_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$mut_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$mut_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$mut_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$mut_rate)$p.value
#substitution rate by ORF (NCBI_SRA_amplicon)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = subst_rate,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("ORF") + ylab("Substitution rate (Count / Length)") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$subst_rate)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$subst_rate)+1e-4)) + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1)
ggsave(filename = "Substitution_rate_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$subst_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$subst_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$subst_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$subst_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$subst_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$subst_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$subst_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$subst_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$subst_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$subst_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$subst_rate);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$subst_rate,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$subst_rate)$p.value

#pN/pS by ORF (NCBI_SRA_amplicon)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = pN_pS,fill=as.character(is_epitope_related))) + geom_violin() + geom_point() + xlab("ORF") + ylab("pN/pS") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pN_pS)+1e-2,1e-2),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pN_pS)+1e-2))
ggsave(filename = "pN_pS_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$pN_pS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$pN_pS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$pN_pS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$pN_pS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$pN_pS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$pN_pS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$pN_pS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$pN_pS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$pN_pS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$pN_pS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$pN_pS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$pN_pS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$pN_pS)$p.value
#dN/dS by ORF (NCBI_SRA_amplicon)
ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = dN_dS,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("ORF") + ylab("dN/dS") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dN_dS)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dN_dS)+1e-4))
ggsave(filename = "dN_dS_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$dN_dS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$dN_dS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$dN_dS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$dN_dS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$dN_dS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$dN_dS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$dN_dS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$dN_dS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$dN_dS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$dN_dS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$dN_dS);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$dN_dS,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$dN_dS)$p.value

#M-K test alpha by ORF (NCBI_SRA_amplicon)
#ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = alpha_MK_Test,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("ORF") + ylab("McDonald-Kreitman test \U003B1") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$alpha_MK_Test)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$alpha_MK_Test)+1e-4))
#ggsave(filename = "MK_test_alpha_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$alpha_MK_Test,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$alpha_MK_Test)$p.value
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$alpha_MK_Test,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$alpha_MK_Test)$p.value
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$alpha_MK_Test,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$alpha_MK_Test)$p.value
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$alpha_MK_Test,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$alpha_MK_Test)$p.value
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$alpha_MK_Test,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$alpha_MK_Test)$p.value
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$alpha_MK_Test,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$alpha_MK_Test)$p.value

#fixation index with pseudocount = (dN/dS* / pN/pS*)
min_value_syn_rates <- min(c(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pN[df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pN!=0], df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pS[df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pS!=0],df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dN[df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dN!=0],df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dS[df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dS!=0]),na.rm=T)
df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index <- ((df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dN+min_value_syn_rates)/(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$dS+min_value_syn_rates))/((df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pN+min_value_syn_rates)/(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$pS+min_value_syn_rates))
df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index <- ifelse(test = is.infinite(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index),yes=NA,no=df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)
# ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = log10(fixation_index),fill=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")))) + geom_violin(width=1.2) + xlab("ORF") + ylab(paste0("Fixation Index : log10(dN/dS to pN/pS ratio)\n *Added pseudocount = ",formatC(min_value_syn_rates,digits = 2,format = "E")," (minimum rate > 0)")) + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme_bw() + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "right") + labs(fill="Epitope sites?") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index[is.finite(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)],na.rm=T),1),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index[is.finite(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)],na.rm=T)))#+ stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)+1e-4))
# ggsave(filename = "Fixation_index_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 18.25, height = 10, units = "cm",dpi = 1200)
# ggsave(filename = "Fixation_index_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.eps", path=output_workspace, width = 18.25, height = 10, units = "cm",dpi = 1200,device=cairo_ps)
#ggplot(data = df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,aes(x=factor(ORF,levels=v_orfs_of_interest),y = fixation_index,fill=factor(as.character(is_epitope_related),levels=c("TRUE","FALSE")))) + geom_violin() + xlab("ORF") + ylab(paste0("Fixation Index : dN/dS to pN/pS ratio\n *Added pseudocount = 1")) + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme_bw() + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "right") + labs(fill="Epitope sites?") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index[is.finite(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)],na.rm=T),1),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index[is.finite(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)],na.rm=T)))#+ stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) #+ scale_y_continuous(breaks=seq(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)+1e-4,1e-4),limits = c(0,max(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon$fixation_index)+1e-4))
#ggsave(filename = "Fixation_index_pseudocount1__in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 18.25, height = 10, units = "cm",dpi = 1200)
#ggsave(filename = "Fixation_index_pseudocount1_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.eps", path=output_workspace, width = 18.25, height = 10, units = "cm",dpi = 1200,device=cairo_ps)
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$fixation_index,na.rm=T);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$fixation_index,na.rm=T);
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$fixation_index,na.rm=T);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$fixation_index,na.rm=T);
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$fixation_index,na.rm=T);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$fixation_index,na.rm=T);
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$fixation_index,na.rm=T);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$fixation_index,na.rm=T);
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$fixation_index,na.rm=T);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$fixation_index,na.rm=T);
#mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$fixation_index,na.rm=T);mean(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$fixation_index,na.rm=T);
#v_pval_fixation_index_diff_in_epitope_vs_out_by_ORF <- c("orf1a"=wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(is_epitope_related))$fixation_index,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1a")&(!is_epitope_related))$fixation_index)$p.value,
#                                                         "orf1b"=wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(is_epitope_related))$fixation_index,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="orf1b")&(!is_epitope_related))$fixation_index)$p.value,
#                                                         "S"=wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(is_epitope_related))$fixation_index,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="S")&(!is_epitope_related))$fixation_index)$p.value,
#                                                         "E"=wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(is_epitope_related))$fixation_index,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="E")&(!is_epitope_related))$fixation_index)$p.value,
#                                                         "M"=wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(is_epitope_related))$fixation_index,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="M")&(!is_epitope_related))$fixation_index)$p.value,
#                                                         "N"=wilcox.test(subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(is_epitope_related))$fixation_index,subset(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,(ORF=="N")&(!is_epitope_related))$fixation_index)$p.value)
#v_corrected_pval_fixation_index_diff_in_epitope_vs_out_by_ORF <- p.adjust(p = v_pval_fixation_index_diff_in_epitope_vs_out_by_ORF,method="fdr")
# 
# # df_coverage_in_epitope_vs_out_of_epitopes_positions_by_ORF_NCBI_SRA_amplicon <- data.frame(in_epitope=unname(vapply(X = c("orf1a","orf1b","M","N","S","E"),FUN= function(the_orf) mean(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(Position%in%v_unique_epitope_positions_with_enough_coverage_NCBI_SRA_amplicon)&(ORF==the_orf)&(!is.na(ORF)))$total_depth,na.rm=T) ,FUN.VALUE = c(0.0))),out_of_epitope=unname(vapply(X = c("orf1a","orf1b","M","N","S","E"),FUN= function(the_orf) mean(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(Position%in%v_non_epitope_sites)&(ORF==the_orf)&(!is.na(ORF)))$total_depth,na.rm=T) ,FUN.VALUE = c(0.0))),stringsAsFactors = F)
# # rownames(df_coverage_in_epitope_vs_out_of_epitopes_positions_by_ORF_NCBI_SRA_amplicon) <- c("orf1a","orf1b","M","N","S","E")
# # df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon <- aggregate(df_variants_site_enough_covered_NCBI_SRA_amplicon$mutation_name,by=list(df_variants_site_enough_covered_NCBI_SRA_amplicon$is_epitope_related,df_variants_site_enough_covered_NCBI_SRA_amplicon$ORF),FUN=function(x) return(length(unique(x))))
# # df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$rate <- df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$x/((vapply(X = 1:nrow(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon),FUN = function(i) ifelse(test = df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.1[i],yes = sum(((v_start_orfs[as.character(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.2[i])]:v_end_orfs[as.character(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.2[i])])%in%v_unique_epitope_positions_with_enough_coverage_NCBI_SRA_amplicon)),no=sum(!(v_start_orfs[as.character(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.2[i])]:v_end_orfs[as.character(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.2[i])])%in%v_unique_epitope_positions_with_enough_coverage_NCBI_SRA_amplicon)),FUN.VALUE = c(0))))
# # df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.1 <- ifelse(test = df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.1, yes = "Epitope-related sites",no = "Other sites")
# # df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.2 <- factor(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon$Group.2,levels=v_orfs)
# # #ggboxplot(subset(df_nb_unique_mutations_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon,Group.2%in%c("orf1a","orf1b","M","N","S","E")), x = "Group.1", y = "rate", color = "Group.1", add = "jitter") + stat_compare_means() + xlab("Group of sites") + ylab("Mutation rate") + scale_color_manual(values=c("tan2","grey60")) #+ geom_text(aes(label = as.character(Group.2)))
# # #ggsave(filename = "Mann_Whitney_Mutation_rate_in_epitope_vs_out_of_epitope_by_ORF_NCBI_SRA_amplicon.png", path=output_workspace, width = 20, height = 15, units = "cm")

#compare mutation and substitution rate in epitopes vs outside (S protein domains)
df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon <- data.frame(Sample=rep(lst_samples_NCBI_SRA_amplicon,each=length(c(TRUE,FALSE))*length(v_S_protein_domains)),is_epitope_related=rep(c(TRUE,FALSE),each=length(lst_samples_NCBI_SRA_amplicon)*length(v_S_protein_domains)),S_protein_domain=rep(v_S_protein_domains,length(lst_samples_NCBI_SRA_amplicon)*length(c(TRUE,FALSE))),nb_mutations=0,nb_fixed_mutations=0,mut_rate=0,subst_rate=0,stringsAsFactors = F)
nb_cores <- nb_cpus
lst_splits <- split(1:nrow(df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon), ceiling(seq_along(1:nrow(df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon))/(nrow(df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon)/nb_cores)))
the_f_parallel_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon <- function(i_cl){
  the_vec<- lst_splits[[i_cl]]
  df_metrics_current_subset <- df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon[the_vec,]
  count_iter <- 0
  for (the_i in 1:nrow(df_metrics_current_subset)){
    df_depth_NCBI_SRA_amplicon_current_sample <- read.csv2(file = paste0(depth_data_wp,"depth_report_NCBI_SRA_amplicon/df_depth_NCBI_SRA_amplicon_",df_metrics_current_subset$Sample[the_i],".csv"),sep = ",",header = F,stringsAsFactors = FALSE)
    colnames(df_depth_NCBI_SRA_amplicon_current_sample) <- c("sample","position","depth")
    df_depth_NCBI_SRA_amplicon_current_sample$ORF <- vapply(X = df_depth_NCBI_SRA_amplicon_current_sample$position,FUN = find_ORF_of_mutation,FUN.VALUE = c(""))
    df_depth_NCBI_SRA_amplicon_current_sample <- subset(df_depth_NCBI_SRA_amplicon_current_sample,ORF=="S")
    df_depth_NCBI_SRA_amplicon_current_sample$pos_in_protein <- ceiling((df_depth_NCBI_SRA_amplicon_current_sample$position - v_start_genes["S"] + 1)/3)
    df_depth_NCBI_SRA_amplicon_current_sample$S_protein_domain <- vapply(X = df_depth_NCBI_SRA_amplicon_current_sample$pos_in_protein,FUN = find_S_protein_domain_of_mutation,FUN.VALUE = c(""))
    df_depth_NCBI_SRA_amplicon_current_sample <- unique(df_depth_NCBI_SRA_amplicon_current_sample)
    v_currentsample_positions_enough_covered <- subset(df_depth_NCBI_SRA_amplicon_current_sample,(depth>=min_cov)&(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i]))$position
    if (df_metrics_current_subset$is_epitope_related[the_i]){
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_unique_epitope_positions,v_currentsample_positions_enough_covered)
    }else{
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_non_epitope_sites,v_currentsample_positions_enough_covered)
    }
    df_metrics_current_subset$nb_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i])&(is_fixed=="No")&(!Position%in%v_positions_inter)&(is_epitope_related==df_metrics_current_subset$is_epitope_related[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_fixed_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i])&(is_fixed=="Yes")&(is_prevalence_above_transmission_threshold)&(is_epitope_related==df_metrics_current_subset$is_epitope_related[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] <- length(v_the_sites_with_enough_cov_for_current_category)
    df_metrics_current_subset$mut_rate[the_i] <- df_metrics_current_subset$nb_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$subst_rate[the_i] <- df_metrics_current_subset$nb_fixed_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$Nb_ss[the_i] <- sum(unname(vapply(X = v_the_sites_with_enough_cov_for_current_category,FUN = calculate_nb_ss_position_in_genome,FUN.VALUE = c(0))),na.rm=T)
    df_metrics_current_subset$Nb_nss[the_i] <- df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] - df_metrics_current_subset$Nb_ss[the_i]
    df_metrics_current_subset$within_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i])&(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$within_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i])&(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i])&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(S_protein_domain==df_metrics_current_subset$S_protein_domain[the_i])&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))

    if (the_i%%100==0){
      print(paste0("[Epitope sites vs others by S_protein_domain (NCBI)] Core ",i_cl,": Step ",the_i," done out of ",nrow(df_metrics_current_subset),"!"))
    }
  }
  df_metrics_current_subset$pN <- df_metrics_current_subset$within_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$pS <- df_metrics_current_subset$within_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$pN_pS <- ifelse(test=df_metrics_current_subset$pS==0,yes=NA,no=df_metrics_current_subset$pN/df_metrics_current_subset$pS)
  df_metrics_current_subset$dN <- df_metrics_current_subset$between_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$dS <- df_metrics_current_subset$between_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$dN_dS <- ifelse(test=df_metrics_current_subset$dS==0,yes=NA,no=df_metrics_current_subset$dN/df_metrics_current_subset$dS)
  df_metrics_current_subset$alpha_MK_Test <- ifelse(test=df_metrics_current_subset$dN_dS==0,yes=NA,no=(1-((df_metrics_current_subset$pN_pS)/(df_metrics_current_subset$dN_dS))))

  return(df_metrics_current_subset)
}
cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_Evo_rates_analyses.txt"))
registerDoParallel(cl)
df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel","Biostrings"))  %dopar% the_f_parallel_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon(i_cl)
stopCluster(cl)
saveRDS(df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon,paste0(output_workspace,"df_metrics_in_epitope_vs_out_of_epitopes_by_ORF_NCBI_SRA_amplicon.rds"))
df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$label <- ifelse(df_metrics_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$is_epitope_related,yes="Epitope sites",no="Other sites")
#within-host mutation rate by S_protein_domain (NCBI_SRA_amplicon)
ggplot(data = df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,aes(x=factor(S_protein_domain,levels=v_S_protein_domains),y = mut_rate,fill=as.character(is_epitope_related))) + geom_violin() + geom_point() + xlab("S protein domain") + ylab("Within-host mutation rate (Count / Length)") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + scale_y_continuous(breaks=seq(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$mut_rate)+1e-2,1e-2),limits = c(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$mut_rate)+1e-2)) + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1)
ggsave(filename = "Mutation_rate_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$mut_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$mut_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$mut_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$mut_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$mut_rate)$p.value
#substitution rate by S_protein_domain (NCBI_SRA_amplicon)
ggplot(data = df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,aes(x=factor(S_protein_domain,levels=v_S_protein_domains),y = subst_rate,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("S protein domain") + ylab("Substitution rate (Count / Length)") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_y_continuous(breaks=seq(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$subst_rate)+1e-4,1e-4),limits = c(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$subst_rate)+1e-4)) + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1)
ggsave(filename = "Substitution_rate_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$subst_rate)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$subst_rate);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$subst_rate); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$subst_rate,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$subst_rate)$p.value

# pN/pS by S_protein_domain (NCBI_SRA_amplicon)
ggplot(data = df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,aes(x=factor(S_protein_domain,levels=v_S_protein_domains),y = pN_pS,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("S protein domain") + ylab("pN/pS") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) # + scale_y_continuous(breaks=seq(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$pN_pS)+1e-2,1e-2),limits = c(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$pN_pS)+1e-2))
ggsave(filename = "pN_pS_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$pN_pS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$pN_pS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$pN_pS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$pN_pS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$pN_pS)$p.value
#dN/dS by S_protein_domain (NCBI_SRA_amplicon)
ggplot(data = df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,aes(x=factor(S_protein_domain,levels=v_S_protein_domains),y = dN_dS,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("S protein domain") + ylab("dN/dS") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) # + scale_y_continuous(breaks=seq(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$dN_dS)+1e-4,1e-4),limits = c(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$dN_dS)+1e-4))
ggsave(filename = "dN_dS_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$dN_dS)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$dN_dS);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$dN_dS); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$dN_dS,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$dN_dS)$p.value

#McDonald-Kreitman test alpha by S_protein_domain (NCBI_SRA_amplicon)
ggplot(data = df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,aes(x=factor(S_protein_domain,levels=v_S_protein_domains),y = alpha_MK_Test,fill=as.character(is_epitope_related))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("S protein domain") + ylab("McDonald-Kreitman test alpha") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + stat_compare_means(method = "kruskal") + facet_wrap(~label,ncol=1) # + scale_y_continuous(breaks=seq(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$alpha_MK_Test)+1e-4,1e-4),limits = c(0,max(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon$alpha_MK_Test)+1e-4))
ggsave(filename = "alpha_MK_Test_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="NTD")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="RBD")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD1")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD2")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CR")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR1")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="CH-BH")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="SD3")&(!is_epitope_related))$alpha_MK_Test)$p.value
mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$alpha_MK_Test);mean(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$alpha_MK_Test); wilcox.test(subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(is_epitope_related))$alpha_MK_Test,subset(df_rates_in_epitope_vs_out_of_epitopes_by_S_protein_domain_NCBI_SRA_amplicon,(S_protein_domain=="HR2-TM-CT")&(!is_epitope_related))$alpha_MK_Test)$p.value

##############
#Identify peptides that are significantly enriched in one group
#df_epitope_frequency_per_group <- aggregate(df_epitopes$patient_ID,by=list(peptide_id=df_epitopes$peptide_id,Group=df_epitopes$Group),FUN=function(x) return(length(x)))
# mtx_epitope_frequency_per_group <- (as.matrix((reshape2::acast(as.data.frame(table(df_epitopes$peptide_id,df_epitopes$Group)), Var1~Var2, value.var="Freq"))))
# # range(p.adjust(vapply(X = rownames(mtx_epitope_frequency_per_group),FUN = function(the_pep) chisq.test(mtx_epitope_frequency_per_group[the_pep,])$p.value,FUN.VALUE = c(0.0)),method = "fdr"))
# df_data_indval_pa <- as.data.frame(t(ifelse(as.matrix((reshape2::acast(as.data.frame(table(df_epitopes$peptide_id,df_epitopes$patient_ID)), Var1~Var2, value.var="Freq")))>0, yes = 1,no=0)))
# res_indvalpa_analysis <- multipatt(x = df_data_indval_pa,cluster = v_group_patient[rownames(df_data_indval_pa)],func = "IndVal.g",duleg=TRUE, max.order = 1,control = how(nperm = 9999),print.perm = TRUE)
# df_res_indvalpa_analysis <- as.data.frame(res_indvalpa_analysis$sign)
# df_signif_res_indval_pa <- subset(df_res_indvalpa_analysis,p.value<=0.05)
# df_signif_res_indval_pa$Genomic_start <- unname(vapply(X = rownames(df_signif_res_indval_pa),FUN = function(x) subset(df_epitopes,peptide_id==x)$Genomic_start[1],FUN.VALUE = c(0)))
# df_signif_res_indval_pa$Genomic_End <- unname(vapply(X = rownames(df_signif_res_indval_pa),FUN = function(x) subset(df_epitopes,peptide_id==x)$Genomic_End[1],FUN.VALUE = c(0)))
# df_signif_res_indval_pa$mutation_rate_NCBI_SRA_amplicon <- unname(vapply(X = 1:nrow(df_signif_res_indval_pa),FUN = function(i) length(unique(subset(df_variants_NCBI_SRA_amplicon,(Position>=(df_signif_res_indval_pa$Genomic_start[i]))&(Position<=(df_signif_res_indval_pa$Genomic_End[i])))$mutation_name))/(df_signif_res_indval_pa$Genomic_End[i]-df_signif_res_indval_pa$Genomic_start[i]+1),FUN.VALUE = c(0)))
# df_signif_res_indval_pa$substitution_rate_NCBI_SRA_amplicon <- unname(vapply(X = 1:nrow(df_signif_res_indval_pa),FUN = function(i) length(unique(subset(df_variants_NCBI_SRA_amplicon,(Position>=(df_signif_res_indval_pa$Genomic_start[i]))&(Position<=(df_signif_res_indval_pa$Genomic_End[i]))&(is_fixed=="Yes"))$mutation_name))/(df_signif_res_indval_pa$Genomic_End[i]-df_signif_res_indval_pa$Genomic_start[i]+1),FUN.VALUE = c(0)))
# names(df_signif_res_indval_pa)[4:6] <- c("Group_with_strongest_association","stat","p_value_association")
# df_signif_res_indval_pa$sequence <- v_seq_peptide[rownames(df_signif_res_indval_pa)]
# df_signif_res_indval_pa_to_save <- df_signif_res_indval_pa
# df_signif_res_indval_pa_to_save$peptide_id <- rownames(df_signif_res_indval_pa_to_save)
# rownames(df_signif_res_indval_pa_to_save) <- NULL
# df_signif_res_indval_pa_to_save <- df_signif_res_indval_pa_to_save[,c("peptide_id","sequence","Group_with_strongest_association","p_value_association","Genomic_start","Genomic_End","mutation_rate_NCBI_SRA_amplicon","substitution_rate_NCBI_SRA_amplicon")]
# #write.table(x=df_signif_res_indval_pa_to_save,file = paste0(output_workspace,"Epitopes_with_significant_association_to_a_specific_group.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)

#import the 4 ancient hCoVs epitopes that mapped to SARS-CoV-2 genome
df_epitopes_HKU1 <- read.csv2(file = paste0(output_workspace,"Epitopes_HKU1_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
df_epitopes_HKU1$Genomic_start <- as.integer(df_epitopes_HKU1$Genomic_start)
df_epitopes_HKU1$Genomic_End <- as.integer(df_epitopes_HKU1$Genomic_End)
df_epitopes_HKU1$Mapping_region <- vapply(X = df_epitopes_HKU1$Genomic_End,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
df_epitopes_HKU1$peptide_id <- NULL
df_epitopes_HKU1$hCoVs_overlap <- NULL
df_epitopes_HKU1 <- subset(df_epitopes_HKU1,(!is.na(Genomic_start))&(!is.na(Genomic_start)))
df_epitopes_HKU1$Mapping_region <- factor(as.character(df_epitopes_HKU1$Mapping_region),intersect(v_orfs,df_epitopes_HKU1$Mapping_region))
df_epitopes_HKU1 <- subset(df_epitopes_HKU1,vapply(X = 1:nrow(df_epitopes_HKU1),FUN = function(i) (return(grepl(pattern = df_epitopes_HKU1$Mapping_region[i],x = df_epitopes_HKU1$Annotated_region[i],fixed = TRUE) )),FUN.VALUE = c(FALSE) ))
df_epitopes_HKU1$Group <- as.character(df_epitopes_HKU1$Group)
df_epitopes_HKU1$RFU <- as.numeric(df_epitopes_HKU1$RFU)
df_epitopes_HKU1 <- subset(df_epitopes_HKU1, RFU>=1000)

df_epitopes_OC43 <- read.csv2(file = paste0(output_workspace,"Epitopes_OC43_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
df_epitopes_OC43$Genomic_start <- as.integer(df_epitopes_OC43$Genomic_start)
df_epitopes_OC43$Genomic_End <- as.integer(df_epitopes_OC43$Genomic_End)
df_epitopes_OC43$Mapping_region <- vapply(X = df_epitopes_OC43$Genomic_End,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
df_epitopes_OC43$peptide_id <- NULL
df_epitopes_OC43$hCoVs_overlap <- NULL
df_epitopes_OC43 <- subset(df_epitopes_OC43,(!is.na(Genomic_start))&(!is.na(Genomic_start)))
df_epitopes_OC43$Mapping_region <- factor(as.character(df_epitopes_OC43$Mapping_region),intersect(v_orfs,df_epitopes_OC43$Mapping_region))
df_epitopes_OC43 <- subset(df_epitopes_OC43,vapply(X = 1:nrow(df_epitopes_OC43),FUN = function(i) (return(grepl(pattern = df_epitopes_OC43$Mapping_region[i],x = df_epitopes_OC43$Annotated_region[i],fixed = TRUE) )),FUN.VALUE = c(FALSE) ))
df_epitopes_OC43$Group <- as.character(df_epitopes_OC43$Group)
df_epitopes_OC43$RFU <- as.numeric(df_epitopes_OC43$RFU)
df_epitopes_OC43 <- subset(df_epitopes_OC43, RFU>=1000)

df_epitopes_NL63 <- read.csv2(file = paste0(output_workspace,"Epitopes_NL63_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
df_epitopes_NL63$Genomic_start <- as.integer(df_epitopes_NL63$Genomic_start)
df_epitopes_NL63$Genomic_End <- as.integer(df_epitopes_NL63$Genomic_End)
df_epitopes_NL63$Mapping_region <- vapply(X = df_epitopes_NL63$Genomic_End,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
df_epitopes_NL63$peptide_id <- NULL
df_epitopes_NL63$hCoVs_overlap <- NULL
df_epitopes_NL63 <- subset(df_epitopes_NL63,(!is.na(Genomic_start))&(!is.na(Genomic_start)))
df_epitopes_NL63$Mapping_region <- factor(as.character(df_epitopes_NL63$Mapping_region),intersect(v_orfs,df_epitopes_NL63$Mapping_region))
df_epitopes_NL63 <- subset(df_epitopes_NL63,vapply(X = 1:nrow(df_epitopes_NL63),FUN = function(i) (return(grepl(pattern = df_epitopes_NL63$Mapping_region[i],x = df_epitopes_NL63$Annotated_region[i],fixed = TRUE) )),FUN.VALUE = c(FALSE) ))
df_epitopes_NL63$Group <- as.character(df_epitopes_NL63$Group)
df_epitopes_NL63$RFU <- as.numeric(df_epitopes_NL63$RFU)
df_epitopes_NL63 <- subset(df_epitopes_NL63, RFU>=1000)

df_epitopes_229E <- read.csv2(file = paste0(output_workspace,"Epitopes_229E_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
df_epitopes_229E$Genomic_start <- as.integer(df_epitopes_229E$Genomic_start)
df_epitopes_229E$Genomic_End <- as.integer(df_epitopes_229E$Genomic_End)
df_epitopes_229E$Mapping_region <- vapply(X = df_epitopes_229E$Genomic_End,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c(""))
df_epitopes_229E$peptide_id <- NULL
df_epitopes_229E$hCoVs_overlap <- NULL
df_epitopes_229E <- subset(df_epitopes_229E,(!is.na(Genomic_start))&(!is.na(Genomic_start)))
df_epitopes_229E$Mapping_region <- factor(as.character(df_epitopes_229E$Mapping_region),intersect(v_orfs,df_epitopes_229E$Mapping_region))
df_epitopes_229E <- subset(df_epitopes_229E,vapply(X = 1:nrow(df_epitopes_229E),FUN = function(i) (return(grepl(pattern = df_epitopes_229E$Mapping_region[i],x = df_epitopes_229E$Annotated_region[i],fixed = TRUE) )),FUN.VALUE = c(FALSE) ))
df_epitopes_229E$Group <- as.character(df_epitopes_229E$Group)
df_epitopes_229E$RFU <- as.numeric(df_epitopes_229E$RFU)
df_epitopes_229E <- subset(df_epitopes_229E, RFU>=1000)

#hCoVs overlap
v_more_ancient_hcovs <- c("HKU1","OC43","NL63","229E")
#lst_df_epitopes_more_ancient_hcovs <- list(HKU1=df_epitopes_HKU1,OC43=df_epitopes_OC43,NL63=df_epitopes_NL63,"229E"=df_epitopes_229E)
df_epitope_overlap_ancient_hcovs <- rbind(df_epitopes_HKU1[,c("Peptide","Genomic_start","Mapping_region","patient_ID")],df_epitopes_OC43[,c("Peptide","Genomic_start","Mapping_region","patient_ID")],df_epitopes_NL63[,c("Peptide","Genomic_start","Mapping_region","patient_ID")],df_epitopes_229E[,c("Peptide","Genomic_start","Mapping_region","patient_ID")])
df_epitope_overlap_ancient_hcovs <- unique(df_epitope_overlap_ancient_hcovs)
df_epitope_overlap_ancient_hcovs <- aggregate(df_epitope_overlap_ancient_hcovs$Peptide,by=list(df_epitope_overlap_ancient_hcovs$Peptide,df_epitope_overlap_ancient_hcovs$Genomic_start,df_epitope_overlap_ancient_hcovs$Mapping_region),FUN=function(x) length(x))
names(df_epitope_overlap_ancient_hcovs) <- c("Peptide","Genomic_start","Mapping_region","Count")
df_epitope_overlap_ancient_hcovs$hcovs_overlap <- paste0("SARS-CoV-2/",vapply(X = df_epitope_overlap_ancient_hcovs$Peptide,FUN = function(the_pep) return(paste0(v_more_ancient_hcovs[c(the_pep%in%df_epitopes_HKU1$Peptide,the_pep%in%df_epitopes_OC43$Peptide,the_pep%in%df_epitopes_NL63$Peptide,the_pep%in%df_epitopes_229E$Peptide)],collapse="/")),FUN.VALUE = c("")))
df_epitope_overlap_ancient_hcovs$hcovs_overlap <- ifelse(test = df_epitope_overlap_ancient_hcovs$hcovs_overlap==paste0(c("SARS-CoV-2",v_more_ancient_hcovs),collapse = "/"),yes="All",no = df_epitope_overlap_ancient_hcovs$hcovs_overlap)

#cairo_ps(filename = paste0(output_workspace,"hCoVs_overlap_for_ALL_Epitopes.eps"), height = 7.8, width=5.9,fallback_resolution = 1200)
#grid.arrange(ggplot(data = df_epitope_overlap_ancient_hcovs) + geom_linerange(mapping = aes(x = Genomic_start,ymin=0, ymax = Count)) + geom_point(mapping = aes(x=Genomic_start,y=Count,col=hcovs_overlap),size=2)+ theme_bw()  + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),legend.position = "none",axis.text.y = element_text(size=12)) + ylab("Prevalence in the dataset (n=15)") + xlab("") + guides(col=guide_legend(title="hCoVs overlap")) + scale_y_continuous(limits = c(-1.5,15),breaks=seq(0,15,1))+ scale_x_continuous(limits = c(0,nchar(genome_refseq)),breaks=seq(0,nchar(genome_refseq),5000)),#ggplot(data = df_epitope_overlap_ancient_hcovs) + geom_smooth(mapping = aes(x=Genomic_start,y=Count,col=hcovs_overlap),method = "loess",size=0.1)+ theme_bw()  + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position = "none") + ylab("LOESS") + xlab("Position")+ guides(col=guide_legend(title="hCoVs overlap")) + scale_y_continuous(limits = c(0,15),breaks=seq(0,15,1))+ scale_x_continuous(limits = c(0,nchar(genome_refseq)),breaks=seq(0,nchar(genome_refseq),5000)), ncol=1)
#dev.off()
#cairo_ps(filename = paste0(output_workspace,"hCoVs_overlap_for_Epitopes_that_are_present_in_most_of_the_samples.eps"), height = 7.8, width=5.9,fallback_resolution = 1200)
#grid.arrange(ggplot(data = subset(df_epitope_overlap_ancient_hcovs,Count>(max(df_epitope_overlap_ancient_hcovs$Count)/2))) + geom_linerange(mapping = aes(x = Genomic_start,ymin=0, ymax = Count)) + geom_point(mapping = aes(x=Genomic_start,y=Count,col=hcovs_overlap),size=3)+ theme_bw()  + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position = "none") + ylab("Prevalence in the dataset (n=15)") + xlab("") + guides(col=guide_legend(title="hCoVs overlap")) + scale_y_continuous(limits = c(-1.5,15),breaks=seq(0,15,1))+ scale_x_continuous(limits = c(0,nchar(genome_refseq)),breaks=seq(0,nchar(genome_refseq),5000)),#ggplot(data =subset(df_epitope_overlap_ancient_hcovs,Count>(max(df_epitope_overlap_ancient_hcovs$Count)/2))) + geom_smooth(mapping = aes(x=Genomic_start,y=Count,col=hcovs_overlap),method = "loess",size=0.1)+ theme_bw()  + theme(title =  element_text(size=12),legend.text = element_text(size = 8),legend.position = "none",axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("LOESS") + xlab("Position")+ guides(col=guide_legend(title="hCoVs overlap")) + scale_y_continuous(limits = c(0,15),breaks=seq(0,15,1))+ scale_x_continuous(limits = c(0,nchar(genome_refseq)),breaks=seq(0,nchar(genome_refseq),5000)), ncol=1)
#dev.off()

df_epitopes_ancient_hcovs <- rbind(df_epitopes_HKU1,df_epitopes_OC43,df_epitopes_NL63,df_epitopes_229E)
df_all_epitopes_ancient_hcovs <- unique(data.frame(Peptide=c(read.csv2(file = paste0(output_workspace,"Epitopes_HKU1_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Peptide,read.csv2(file = paste0(output_workspace,"Epitopes_OC43_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Peptide,read.csv2(file = paste0(output_workspace,"Epitopes_NL63_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Peptide, read.csv2(file = paste0(output_workspace,"Epitopes_229E_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Peptide),Genomic_start=as.integer(c(read.csv2(file = paste0(output_workspace,"Epitopes_HKU1_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Genomic_start,read.csv2(file = paste0(output_workspace,"Epitopes_OC43_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Genomic_start,read.csv2(file = paste0(output_workspace,"Epitopes_NL63_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Genomic_start, read.csv2(file = paste0(output_workspace,"Epitopes_229E_mapped.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)$Genomic_start),stringsAsFactors = FALSE)))
df_all_epitopes_ancient_hcovs$Mapping_region <- ifelse(test = is.na(df_all_epitopes_ancient_hcovs$Genomic_start),yes = "NA",no = vapply(X = df_all_epitopes_ancient_hcovs$Genomic_start,FUN = find_ORF_of_mutation,FUN.VALUE = c("")))
v_lst_id_epitope_seq_ancient_hcovs_in_order <- 1:length(sort(unique(df_all_epitopes_ancient_hcovs$Peptide),decreasing = FALSE))
names(v_lst_id_epitope_seq_ancient_hcovs_in_order) <- sort(unique(df_all_epitopes_ancient_hcovs$Peptide),decreasing = FALSE)
df_epitopes_ancient_hcovs$peptide_id <- paste0("EhCov_",df_epitopes_ancient_hcovs$Mapping_region,"_",unname(v_lst_id_epitope_seq_ancient_hcovs_in_order[df_epitopes_ancient_hcovs$Peptide]))
df_epitope_overlap_ancient_hcovs$peptide_id <- paste0("EhCov_",df_epitope_overlap_ancient_hcovs$Mapping_region,"_",unname(v_lst_id_epitope_seq_ancient_hcovs_in_order[df_epitope_overlap_ancient_hcovs$Peptide]))
df_all_epitopes_ancient_hcovs$peptide_id <- paste0("EhCov_",as.character(df_all_epitopes_ancient_hcovs$Mapping_region),"_",unname(v_lst_id_epitope_seq_ancient_hcovs_in_order[df_all_epitopes_ancient_hcovs$Peptide]))
rownames(df_all_epitopes_ancient_hcovs) <- df_all_epitopes_ancient_hcovs$peptide_id

df_sars_cov_2_epitopes <- readRDS(file = paste0(output_workspace,"df_sars_cov_2_epitopes.rds"))
df_sars_cov_2_epitopes <- subset(df_sars_cov_2_epitopes, peptide_id %in% df_epitopes$peptide_id) #filter for RFU >= 1000

#RFU across ORFs and groups
#p <- ggboxplot(data = df_epitopes_ancient_hcovs, x = "Mapping_region", y="RFU",color = "Group",add = "jitter")+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Genomic region") +scale_y_continuous(limits = c(0,max(df_epitopes_ancient_hcovs$RFU)+10000),breaks=seq(0,max(df_epitopes_ancient_hcovs$RFU)+10000,10000))
#facet(p +  stat_compare_means(), facet.by = "Group", ncol = 1)
#ggsave(filename = "Ancient_hCoVs_RFU_by_ORF_and_Groups.png", path=output_workspace, width = 20, height = 20, units = "cm",dpi = 1200)

#RFU across groups
#ggboxplot(data = df_epitopes_ancient_hcovs, x = "Group", y="RFU",color = "Group",add = "jitter") +  stat_compare_means() + theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Group")
#ggsave(filename = "Ancient_hCoVs_RFU_by_Groups.png", path=output_workspace, width = 20, height = 15, units = "cm",dpi = 1200)

#RFU across Antibody and groups
#p <- ggboxplot(data = df_epitopes_ancient_hcovs, x = "Antibody", y="RFU",color = "Group",add = "jitter")+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12)) + ylab("RFU") + xlab("Antibody") +scale_y_continuous(limits = c(0,max(df_epitopes_ancient_hcovs$RFU)+10000),breaks=seq(0,max(df_epitopes_ancient_hcovs$RFU)+10000,10000))
#facet(p +  stat_compare_means(), facet.by = "Group", ncol = 1)
#ggsave(filename = "Ancient_hCoVs_RFU_by_Antibody_and_Groups.png", path=output_workspace, width = 20, height = 20, units = "cm",dpi = 1200)

# #create Jalview annotation file
# df_positions_epitope_proteome_genome <- NULL
# df_positions_epitope_proteome_genome$Genomic_Position <- 1:nchar(genome_refseq)
# df_positions_epitope_proteome_genome <- as.data.frame(df_positions_epitope_proteome_genome)
# df_positions_epitope_proteome_genome$ORF <- unname(vapply(X = df_positions_epitope_proteome_genome$Genomic_Position,FUN = function(x) return(find_ORF_of_mutation(the_site_position = x)),FUN.VALUE = c("")))
# df_positions_epitope_proteome_genome <- subset(df_positions_epitope_proteome_genome,!is.na(ORF))
# df_positions_epitope_proteome_genome$pos_in_protein <- unname(ceiling((df_positions_epitope_proteome_genome$Genomic_Position - v_start_orfs[df_positions_epitope_proteome_genome$ORF] + 1)/3))
# df_positions_epitope_proteome_genome$is_epitope_related <- df_positions_epitope_proteome_genome$Genomic_Position%in% v_unique_epitope_positions
# for (current_orf in c("orf1a","orf1b","S","E","M","N")){
#   v_pos_in_prot_to_highlight <- sort(unique(subset(df_positions_epitope_proteome_genome,(ORF==current_orf)&(is_epitope_related))$pos_in_protein))
#   df_align_colour_current_orf <- data.frame(charact_align = unlist(strsplit(x = seqinr::getSequence(object = toupper(read.fasta(paste0(output_workspace,"hCoVs_alignments/",paste0(current_orf,"_aligned.fasta")),seqtype = "AA",as.string = TRUE,forceDNAtolower = FALSE)$`SARS-CoV-2`),as.string = TRUE)[[1]],split="")),stringsAsFactors = F)
#   df_align_colour_current_orf$pos_in_align <- 1:(nrow(df_align_colour_current_orf))
#   df_align_colour_current_orf <- subset(df_align_colour_current_orf,charact_align!="-")
#   df_align_colour_current_orf$pos_in_prot <- 1:nrow(df_align_colour_current_orf)
#   current_v_pos_in_alignment_to_highlight <- subset(df_align_colour_current_orf,pos_in_prot%in%v_pos_in_prot_to_highlight)$pos_in_align
#   sink(paste0(output_workspace,"hCoVs_alignments/",current_orf,"_annotations.txt"))
#   cat("JALVIEW_ANNOTATION\n")
#   i <- 1
#   for (current_pos in current_v_pos_in_alignment_to_highlight){
#     cat(paste0("SEQUENCE_GROUP\tGroup_",i,"\t",current_pos,"\t",current_pos,"\t*\n"),append = T)
#     i <- i + 1
#   }
#   i <- 1
#   for (current_pos in current_v_pos_in_alignment_to_highlight){
#     cat(paste0("PROPERTIES\tGroup_",i,"\toutlineColour=red\n"),append = T)
#     i <- i + 1
#   }
#   sink()
# }

# #pairwise alignments between SARS-CoV-2 epitopes and 4 endemic hCoVs epitopes
# nb_cores <- nb_cpus
# lst_splits <- split(1:nrow(df_sars_cov_2_epitopes), ceiling(seq_along(1:nrow(df_sars_cov_2_epitopes))/(nrow(df_sars_cov_2_epitopes)/nb_cores)))
# the_f_parallel <- function(i_cl){
#   the_vec<- lst_splits[[i_cl]]
#   df_pairwise_align_score <- NULL
#   data("PAM120")
#   count_iter <- 0
#   for (i_epitope_sars_cov_2 in the_vec){
#     df_pairwise_align_score <- rbind(df_pairwise_align_score,data.frame(id_sars_cov_2_epitope=rownames(df_sars_cov_2_epitopes)[i_epitope_sars_cov_2],id_EhCovs_epitope=rownames(df_all_epitopes_ancient_hcovs),score=vapply(X = rownames(df_all_epitopes_ancient_hcovs),FUN = function(current_ep_Ehcovs) return(pairwiseAlignment(pattern = AAString(df_sars_cov_2_epitopes$Peptide[i_epitope_sars_cov_2]),subject = AAString(df_all_epitopes_ancient_hcovs[current_ep_Ehcovs,"Peptide"]),  substitutionMatrix = PAM120,type="global",gapOpening = 6, gapExtension = 4,scoreOnly=T)[1]),FUN.VALUE = c(0)),stringsAsFactors = FALSE))
#     count_iter <- count_iter + 1
#     if (i_epitope_sars_cov_2%%10==0){
#       print(paste0("Core ",i_cl,": ",count_iter," SARS-CoV-2 epitopes fully compared out of ",length(the_vec)))
#     }
#   }
#   return(df_pairwise_align_score)
# }
# cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_pairwise_align_sc2_vs_EhCoVs.txt"))
# registerDoParallel(cl)
# df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel","Biostrings"))  %dopar% the_f_parallel(i_cl)
# stopCluster(cl)
# #saveRDS(object = df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes,file = paste0(output_workspace,"df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes.rds"))

#compare proportion of shared epitopes
df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes <- readRDS(file = paste0(output_workspace,"df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes.rds"))
df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes <- subset(df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes,(id_sars_cov_2_epitope%in%df_epitopes$peptide_id)&(id_EhCovs_epitope%in%df_epitopes_ancient_hcovs$peptide_id))
##ggplot(data=df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes) + geom_density(mapping=aes(x=score)) + xlab("PAM120 (gapOpening = 6, gapExtension = 4)")

# png(filename = paste0(output_workspace,"Distribution_SC2_vs_EhCoVs_epitopes_PAM_score.png"),width = 8000,height = 8000,units="px",res=600)
# plot(density(df_scores_pairwise_alignments_sars_cov_2_vs_Ehcovs_epitopes$score),xlab="Epitopes pairwise alignment score SARS-CoV-2 vs EhCoVs\n(PAM120, gapOpening = 6 and gapExtension = 4)",ylab="Density",main="")
# dev.off()

#import conservation scores into one dataframe
df_conservation_scores <- NULL
for (current_orf in c("orf1a","orf1b","S","E","M","N")){
  df_to_add <- read.csv2(file = paste0(output_workspace,"hCoVs_alignments/",current_orf,"_conservation_scores.csv"),sep = ",",header = TRUE,stringsAsFactors = FALSE)
  df_to_add$ORF <- current_orf
  df_to_add$pos_in_alignment <- 1:nrow(df_to_add)
  df_to_add$char_sc2_in_align <- unlist(strsplit(x = seqinr::getSequence(object = toupper(read.fasta(paste0(output_workspace,"hCoVs_alignments/",paste0(current_orf,"_aligned.fasta")),seqtype = "AA",as.string = TRUE,forceDNAtolower = FALSE)$`SARS-CoV-2`),as.string = TRUE)[[1]],split=""))
  df_to_add <- subset(df_to_add, char_sc2_in_align!="-")
  df_to_add$pos_in_protein <- 1:nrow(df_to_add)
  df_to_add <- df_to_add[,c("ORF","pos_in_alignment","pos_in_protein","char_sc2_in_align","pcp_conservation_score")]
  df_conservation_scores <- rbind(df_conservation_scores,df_to_add)
}
df_conservation_scores$pcp_conservation_score <- as.numeric(df_conservation_scores$pcp_conservation_score)
#calculate average conservation scores and number of perfectly conserved sites
df_epitopes$avg_pcp_conservation_score <- unname(vapply(X = 1:nrow(df_epitopes),FUN = function(i) mean(subset(df_conservation_scores,(pos_in_protein>=ceiling((df_epitopes$Genomic_start[i]-v_start_orfs[as.character(df_epitopes$Mapping_region[i])]+1)/3))&(pos_in_protein<=ceiling((df_epitopes$Genomic_End[i]-unname(v_start_orfs[as.character(df_epitopes$Mapping_region[i])])+1)/3))&(ORF==as.character(df_epitopes$Mapping_region[i])))$pcp_conservation_score,na.rm=T),FUN.VALUE = c(0.0)))
df_epitopes$nb_perfectly_conserved_residues <- unname(vapply(X = 1:nrow(df_epitopes),FUN = function(i) sum(subset(df_conservation_scores,(pos_in_protein>=ceiling((df_epitopes$Genomic_start[i]-v_start_orfs[as.character(df_epitopes$Mapping_region[i])]+1)/3))&(pos_in_protein<=ceiling((df_epitopes$Genomic_End[i]-unname(v_start_orfs[as.character(df_epitopes$Mapping_region[i])])+1)/3))&(ORF==as.character(df_epitopes$Mapping_region[i])))$pcp_conservation_score==11.0),FUN.VALUE = c(0)))
#df_epitopes$Mapping_region <- factor(df_epitopes$Mapping_region,levels=names(palette_orfs_epitopes))

#Figures avg_pcp_conservation_score and nb_perfectly_conserved_residues_per_epitope across groups and ORFS
list_comp_groups <- list(c("1", "2"), c("1", "3"), c("2", "3"))

#patients average RFU sars-cov-2 vs average RFU ehcovs
df_avg_immune_responses_sc2_vs_ehcovs <- data.frame(patient=unique(df_epitopes$patient_ID),stringsAsFactors = F)
df_avg_immune_responses_sc2_vs_ehcovs$avg_sc2_RFU <- unname(vapply(X=df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) mean(subset(df_epitopes,patient_ID==x)$RFU,na.rm=T),FUN.VALUE = c(0.0)))
df_avg_immune_responses_sc2_vs_ehcovs$avg_ehcovs_RFU <- unname(vapply(X=df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) mean(subset(df_epitopes_ancient_hcovs,patient_ID==x)$RFU,na.rm=T),FUN.VALUE = c(0.0)))
df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes <- unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(avg_pcp_conservation_score>=6))$peptide_id)),FUN.VALUE = c(0)))#unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes_ancient_hcovs,patient_ID==x)$peptide_id)),FUN.VALUE = c(0)))
df_avg_immune_responses_sc2_vs_ehcovs$nb_epitopes <- unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x))$peptide_id)),FUN.VALUE = c(0)))
df_avg_immune_responses_sc2_vs_ehcovs$nb_epitopes_IgA <- unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(Antibody=="IgA"))$peptide_id)),FUN.VALUE = c(0)))
df_avg_immune_responses_sc2_vs_ehcovs$nb_epitopes_IgG <- unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(Antibody=="IgG"))$peptide_id)),FUN.VALUE = c(0)))
df_avg_immune_responses_sc2_vs_ehcovs$Group <- v_group_patient[df_avg_immune_responses_sc2_vs_ehcovs$patient]
df_avg_immune_responses_sc2_vs_ehcovs$pos_neg <- ifelse(test = df_avg_immune_responses_sc2_vs_ehcovs$Group%in%c(1,2),yes="positive",no="negative")

#Proportion of sc2 perfectly conserved sites that are epitopes in one the 4 hCoVs
get_pos_in_prot_ehcovs_epitopes <- function(the_orf){
  df_current_epitopes <- subset(df_epitopes_ancient_hcovs,Mapping_region==the_orf)
  v_out <- NULL
  if(nrow(df_current_epitopes)==0){
    return(NA)
  }
  for (j in 1:nrow(df_current_epitopes)){
    v_out <- c(v_out,(ceiling((df_current_epitopes$Genomic_start[j]-v_start_orfs[as.character(df_current_epitopes$Mapping_region)[j]]+1)/3)):(ceiling((df_current_epitopes$Genomic_End[j]-v_start_orfs[as.character(df_current_epitopes$Mapping_region)[j]]+1)/3)))
  }
  return(sort(unique(v_out)))
}
lst_orfs_pos_in_prot_ehcovs_epitopes <- NULL
for (current_orf in names(palette_orfs_epitopes)){
  lst_orfs_pos_in_prot_ehcovs_epitopes <- c(lst_orfs_pos_in_prot_ehcovs_epitopes,list(c(get_pos_in_prot_ehcovs_epitopes(the_orf = current_orf))))
}

names(lst_orfs_pos_in_prot_ehcovs_epitopes) <- names(palette_orfs_epitopes)
df_sc2_perfectly_conserved_sites <- subset(df_conservation_scores,pcp_conservation_score==11)
proportion_sc2_perfectly_conserved_sites_associated_to_cross_reactivity <- sum(unname(vapply(X = 1:nrow(df_sc2_perfectly_conserved_sites),FUN = function(i) ifelse(test = df_sc2_perfectly_conserved_sites$ORF[i] %in% df_epitopes_ancient_hcovs$Mapping_region ,yes=df_sc2_perfectly_conserved_sites$pos_in_protein[i]%in%(lst_orfs_pos_in_prot_ehcovs_epitopes[[df_sc2_perfectly_conserved_sites$ORF[i]]]),no = F),FUN.VALUE = c(T))))/nrow(df_sc2_perfectly_conserved_sites)

#correlate sc2 epitope RFU to best match PAM score
#ggplotregression(fit = lm(formula = y~x,data = data.frame(y=df_sars_cov_2_epitopes$avg_RFU,x=df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope)),ggsave_path = output_workspace,the_filename = paste0("avg_RFU_vs_PAM_score_best_match.png"),xlabl = paste0("PAM score of the best match\nbetween a SARS-CoV-2 epitope and EhCoVs epitopes"),ylabl = "Average immune response to the epitope (average RFU)")
##ggplotregression(fit = lm(formula = y~x,data = data.frame(y=df_sars_cov_2_epitopes$prevalence,x=df_sars_cov_2_epitopes$avg_pcp_conservation_score)),ggsave_path = output_workspace,the_filename = paste0("Prevalence_vs_avg_conservation_score.png"),xlabl = paste0("Average P.C.P. conservation score"),ylabl = "Epitope prevalence")

#Epitope cross-reactivity profile (Heatmap)
#explore the use of df_epitope_overlap_ancient_hcovs
mtx_pres_abs_cross_reactivity_immunity_related_epitopes <- matrix(0,ncol=length(c("HKU1","NL63","OC43","229E")),nrow=nrow(df_epitope_overlap_ancient_hcovs))
rownames(mtx_pres_abs_cross_reactivity_immunity_related_epitopes) <- df_epitope_overlap_ancient_hcovs$peptide_id
colnames(mtx_pres_abs_cross_reactivity_immunity_related_epitopes) <- c("HKU1","NL63","OC43","229E")
for (i in 1:nrow(mtx_pres_abs_cross_reactivity_immunity_related_epitopes)){
  mtx_pres_abs_cross_reactivity_immunity_related_epitopes[i,] <- as.integer(colnames(mtx_pres_abs_cross_reactivity_immunity_related_epitopes) %in% strsplit(x = df_epitope_overlap_ancient_hcovs$hcovs_overlap[i],"/")[[1]])
}
#png(filename = paste0(output_workspace,"Heatmap_mtx_pres_abs_sc2_cross_reactive_epitopes_across_EhCoVs.png"),width = 6000,height = 8000,units="px",res=600)
#heatmap.2(x = mtx_pres_abs_cross_reactivity_immunity_related_epitopes, distfun = function(x) dist(x, method = "binary"), hclustfun = function(d) hclust(d,method = "ward.D2"),main = "Presence (black) / absence (white)",trace="none",scale="none", labRow = NA,cexRow = 1,cexCol = 1,xlab = "Endemic human coronavirus",ylab="SARS-CoV-2 epitope",col = colorRampPalette(c("white","black"), space = "rgb")(100),key = FALSE)
#dev.off()

#Explore different cross-reactivity cut-offs
df_cross_reactivity_cutoffs <- data.frame(cutoff_value=c(seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25),seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,1)),cutoff_type=c(rep("Cut-off on the average\np.c.p conservation score",length(seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25))),rep("Cut-off on the\nbest match PAM score",length(seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,1)))))
df_cross_reactivity_cutoffs$p_value <- unname(vapply(X = 1:nrow(df_cross_reactivity_cutoffs),FUN = function(i) ifelse(test=df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score",yes=wilcox.test(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score<df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU,subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU)$p.value,no = wilcox.test(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope<df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU,subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU)$p.value),FUN.VALUE = c(0.0)))
df_cross_reactivity_cutoffs$normalized_bin_size_difference <- unname(vapply(X = 1:nrow(df_cross_reactivity_cutoffs),FUN = function(i) ifelse(test=df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score",yes=abs(nrow(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score<df_cross_reactivity_cutoffs$cutoff_value[i]))- nrow(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i]))),no = abs(nrow(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope<df_cross_reactivity_cutoffs$cutoff_value[i]))-nrow(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i]))) ),FUN.VALUE = c(0)))
df_cross_reactivity_cutoffs$normalized_bin_size_difference <- 5*scale(df_cross_reactivity_cutoffs$normalized_bin_size_difference,center = F,scale=T)
df_cross_reactivity_cutoffs$normalized_bin_size_difference <- unname(vapply(X = 1:nrow(df_cross_reactivity_cutoffs),FUN = function(i) ifelse(test=df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score",yes=abs(nrow(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score<df_cross_reactivity_cutoffs$cutoff_value[i]))- nrow(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i]))),no = abs(nrow(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope<df_cross_reactivity_cutoffs$cutoff_value[i]))-nrow(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i]))) ),FUN.VALUE = c(0)))
df_cross_reactivity_cutoffs$sign_bin_size_difference <- unname(vapply(X = 1:nrow(df_cross_reactivity_cutoffs),FUN = function(i) ifelse(test=df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score",yes=sign(nrow(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i]))- nrow(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score<df_cross_reactivity_cutoffs$cutoff_value[i]))),no = sign(nrow(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i]))-nrow(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope<df_cross_reactivity_cutoffs$cutoff_value[i]))) ),FUN.VALUE = c(0)))
df_cross_reactivity_cutoffs$sign_mean_difference <- unname(vapply(X = 1:nrow(df_cross_reactivity_cutoffs),FUN = function(i) ifelse(test=df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score",yes=sign(mean(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU,na.rm=T)- mean(subset(df_sars_cov_2_epitopes,avg_pcp_conservation_score<df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU,na.rm=T)),no = sign(mean(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU,na.rm=T)-mean(subset(df_sars_cov_2_epitopes,PAM_score_best_match_with_a_Ehcovs_epitope<df_cross_reactivity_cutoffs$cutoff_value[i])$avg_RFU,na.rm=T)) ),FUN.VALUE = c(0)))
#assess the effect of the cut-offs on avg_RFU~nb_cross_reactive_epitopes
df_cross_reactivity_cutoffs$p_value_avg_RFU_vs_nb_cross_reactive_epitopes <- NA
df_cross_reactivity_cutoffs$sign_slope_avg_RFU_vs_nb_cross_reactive_epitopes <- NA
for (i in 1:nrow(df_cross_reactivity_cutoffs)){
  if (df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score"){
    cp_df_avg_immune_responses_sc2_vs_ehcovs <- df_avg_immune_responses_sc2_vs_ehcovs
    cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes <- unname(vapply(X = cp_df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i]))$peptide_id)),FUN.VALUE = c(0)))
    coeficients_summary_fit <- coefficients(summary(lm(cp_df_avg_immune_responses_sc2_vs_ehcovs$avg_sc2_RFU~cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes)))
    df_cross_reactivity_cutoffs$p_value_avg_RFU_vs_nb_cross_reactive_epitopes[i] <- coeficients_summary_fit[2,4]
    df_cross_reactivity_cutoffs$sign_slope_avg_RFU_vs_nb_cross_reactive_epitopes[i] <- sign(coeficients_summary_fit[2,1])
  }else{
    cp_df_avg_immune_responses_sc2_vs_ehcovs <- df_avg_immune_responses_sc2_vs_ehcovs
    cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes <- unname(vapply(X = cp_df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) sum((subset(df_sars_cov_2_epitopes,peptide_id%in%(subset(df_epitopes,(patient_ID==x))$peptide_id))$PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i])),FUN.VALUE = c(0)))
    coeficients_summary_fit <- coefficients(summary(lm(cp_df_avg_immune_responses_sc2_vs_ehcovs$avg_sc2_RFU~cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes)))
    df_cross_reactivity_cutoffs$p_value_avg_RFU_vs_nb_cross_reactive_epitopes[i] <- coeficients_summary_fit[2,4]
    df_cross_reactivity_cutoffs$sign_slope_avg_RFU_vs_nb_cross_reactive_epitopes[i] <- sign(coeficients_summary_fit[2,1])
  }
}
remove(cp_df_avg_immune_responses_sc2_vs_ehcovs)
#assess the effect of the cut-offs on nb_cross_reactive_epitopes_per_patient~Group
df_cross_reactivity_cutoffs$p_value_nb_cross_reactive_epitopes_per_patient_vs_Group <- NA
for (i in 1:nrow(df_cross_reactivity_cutoffs)){
  if (df_cross_reactivity_cutoffs$cutoff_type[i]=="Cut-off on the average\np.c.p conservation score"){
    cp_df_avg_immune_responses_sc2_vs_ehcovs <- df_avg_immune_responses_sc2_vs_ehcovs
    cp_df_avg_immune_responses_sc2_vs_ehcovs$Group <- as.factor(cp_df_avg_immune_responses_sc2_vs_ehcovs$Group)
    cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes <- unname(vapply(X = cp_df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(avg_pcp_conservation_score>=df_cross_reactivity_cutoffs$cutoff_value[i]))$peptide_id)),FUN.VALUE = c(0)))
    current_fit <-lm(cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes~cp_df_avg_immune_responses_sc2_vs_ehcovs$Group)
    coeficients_summary_fit <- coefficients(summary(current_fit))
    df_cross_reactivity_cutoffs$p_value_nb_cross_reactive_epitopes_per_patient_vs_Group[i] <- broom::glance(current_fit)$p.value
  }else{
    cp_df_avg_immune_responses_sc2_vs_ehcovs <- df_avg_immune_responses_sc2_vs_ehcovs
    cp_df_avg_immune_responses_sc2_vs_ehcovs$Group <- as.factor(cp_df_avg_immune_responses_sc2_vs_ehcovs$Group)
    cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes <- unname(vapply(X = cp_df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) sum((subset(df_sars_cov_2_epitopes,peptide_id%in%(subset(df_epitopes,(patient_ID==x))$peptide_id))$PAM_score_best_match_with_a_Ehcovs_epitope>=df_cross_reactivity_cutoffs$cutoff_value[i])),FUN.VALUE = c(0)))
    current_fit <-lm(cp_df_avg_immune_responses_sc2_vs_ehcovs$nb_cross_reactive_epitopes~cp_df_avg_immune_responses_sc2_vs_ehcovs$Group)
    coeficients_summary_fit <- coefficients(summary(current_fit))
    df_cross_reactivity_cutoffs$p_value_nb_cross_reactive_epitopes_per_patient_vs_Group[i] <- broom::glance(current_fit)$p.value
  }
}
remove(cp_df_avg_immune_responses_sc2_vs_ehcovs)
#Plots illustrating the cross-reactivity Cut-offs' effects
#RFU cross-reactive vs RFU SC2-specific
#ggplot(data = subset(df_cross_reactivity_cutoffs,cutoff_type=="Cut-off on the average\np.c.p conservation score"),mapping = aes(x = cutoff_value, y=-log10(p_value)))+ geom_point(mapping=aes(size=normalized_bin_size_difference,col=as.character(sign_mean_difference))) + scale_color_manual(values = c("-1"="red","1"="blue")) + theme_bw()+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position="none") + ylab("-log10(p-value)\nRFU cross-reactive vs SARS-CoV-2-specific epitopes") + xlab("Cut-off value for defining cross-reactive epitopes\n(Average p.c.p. conservation score)") + geom_hline(yintercept = -log10(0.05),lty=2,col="red") +scale_x_continuous(breaks=seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25),limits = range(seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25))) +geom_vline(xintercept = 6)
#ggsave(filename = "pvalue_avg_RFU_cross-reactive_epitopes_vs_SC2_specific_eptopes_at_different_avg_pcp_conservation_score_cut-offs.eps", path=output_workspace, width = 17, height = 15, units = "cm",device = cairo_ps,dpi = 1200)
#ggplot(data = subset(df_cross_reactivity_cutoffs,cutoff_type=="Cut-off on the\nbest match PAM score"),mapping = aes(x = cutoff_value, y=-log10(p_value))) + geom_point(mapping=aes(size=normalized_bin_size_difference,col=as.character(sign_mean_difference))) + scale_color_manual(values = c("-1"="red","1"="blue")) + theme_bw()+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position="none") + ylab("-log10(p-value)\nRFU cross-reactive vs SARS-CoV-2-specific epitopes") + xlab("Cut-off value for defining cross-reactive epitopes\n(Best match PAM score)") + geom_hline(yintercept = -log10(0.05),lty=2,col="red") +scale_x_continuous(breaks=seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,2),limits = range(seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,2)))
#ggsave(filename = "pvalue_avg_RFU_cross-reactive_epitopes_vs_SC2_specific_eptopes_at_different_cut-offs_on_best_match_PAM_score.eps", path=output_workspace, width = 17, height = 15, units = "cm",device = cairo_ps,dpi = 1200)
#avg_RFU vs Nb_cross_reactive_epitopes
#ggplot(data = subset(df_cross_reactivity_cutoffs,cutoff_type=="Cut-off on the average\np.c.p conservation score"),mapping = aes(x = cutoff_value, y=-log10(p_value_avg_RFU_vs_nb_cross_reactive_epitopes)))+ geom_point(mapping=aes(size=normalized_bin_size_difference,col=as.character(sign_slope_avg_RFU_vs_nb_cross_reactive_epitopes))) + scale_color_manual(values = c("-1"="red","1"="blue")) + theme_bw()+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position="none") + ylab("-log10(p-value)\navreage RFU ~ Number of cross-reactive epitopes") + xlab("Cut-off value for defining cross-reactive epitopes\n(Average p.c.p. conservation score)") + geom_hline(yintercept = -log10(0.05),lty=2,col="red") +scale_x_continuous(breaks=seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25),limits = range(seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25))) +geom_vline(xintercept = 6)
#ggsave(filename = "pvalue_avg_RFU_vs_nb_cross_reactive_epitopes_at_different_avg_pcp_conservation_score_cut-offs.eps", path=output_workspace, width = 17, height = 15, units = "cm",device = cairo_ps,dpi = 1200)
#ggplot(data = subset(df_cross_reactivity_cutoffs,cutoff_type=="Cut-off on the\nbest match PAM score"),mapping = aes(x = cutoff_value, y=-log10(p_value_avg_RFU_vs_nb_cross_reactive_epitopes))) + geom_point(mapping=aes(size=normalized_bin_size_difference,col=as.character(sign_slope_avg_RFU_vs_nb_cross_reactive_epitopes))) + scale_color_manual(values = c("-1"="red","1"="blue")) + theme_bw()+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position="none") + ylab("-log10(p-value)\navreage RFU ~ Number of cross-reactive epitopes") + xlab("Cut-off value for defining cross-reactive epitopes\n(Best match PAM score)") + geom_hline(yintercept = -log10(0.05),lty=2,col="red") +scale_x_continuous(breaks=seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,2),limits = range(seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,2)))
#ggsave(filename = "pvalue_avg_RFU_vs_nb_cross_reactive_epitopes_at_different_cut-offs_on_best_match_PAM_score.eps", path=output_workspace, width = 17, height = 15, units = "cm",device = cairo_ps,dpi = 1200)
#nb_cross_reactive_epitopes_per_patient~Group
#ggplot(data = subset(df_cross_reactivity_cutoffs,cutoff_type=="Cut-off on the average\np.c.p conservation score"),mapping = aes(x = cutoff_value, y=-log10(p_value_nb_cross_reactive_epitopes_per_patient_vs_Group)))+ geom_point(mapping=aes(size=normalized_bin_size_difference)) + theme_bw()+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position="none") + ylab("-log10(p-value)\nNumber of cross-reactive epitopes per patient vs Group") + xlab("Cut-off value for defining cross-reactive epitopes\n(Average p.c.p. conservation score)") + geom_hline(yintercept = -log10(0.05),lty=2,col="red") +scale_x_continuous(breaks=seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25),limits = range(seq(min(floor(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)+1,max(ceiling(df_sars_cov_2_epitopes$avg_pcp_conservation_score),na.rm=T)-1,0.25))) +geom_vline(xintercept = 6)
#ggsave(filename = "pvalue_nb_cross_reactive_epitopes_per_patient_vs_Group_at_different_avg_pcp_conservation_score_cut-offs.eps", path=output_workspace, width = 17, height = 15, units = "cm",device = cairo_ps,dpi = 1200)
#ggplot(data = subset(df_cross_reactivity_cutoffs,cutoff_type=="Cut-off on the\nbest match PAM score"),mapping = aes(x = cutoff_value, y=-log10(p_value_nb_cross_reactive_epitopes_per_patient_vs_Group))) + geom_point(mapping=aes(size=normalized_bin_size_difference)) + theme_bw()+ theme(title =  element_text(size=12),legend.text = element_text(size = 8),axis.text.x = element_text(angle = 60,hjust = 1,size=10),axis.text.y = element_text(size=12),legend.position="none") + ylab("-log10(p-value)\nNumber of cross-reactive epitopes per patient vs Group") + xlab("Cut-off value for defining cross-reactive epitopes\n(Best match PAM score)") + geom_hline(yintercept = -log10(0.05),lty=2,col="red") +scale_x_continuous(breaks=seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,2),limits = range(seq(min(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)+1,max(df_sars_cov_2_epitopes$PAM_score_best_match_with_a_Ehcovs_epitope,na.rm=T)-1,2)))
#ggsave(filename = "pvalue_nb_cross_reactive_epitopes_per_patient_vs_Group_at_different_cut-offs_on_best_match_PAM_score.eps", path=output_workspace, width = 17, height = 15, units = "cm",device = cairo_ps,dpi = 1200)

#Evolution rates Cross-reactive vs SC2-specific epitopes
df_high_confidence_epitope_metrics <- readRDS(file = paste0(output_workspace,"df_high_confidence_epitope_metrics.rds"))
df_epitopes$is_cross_reactive <- NA
df_epitopes$is_cross_reactive <- unname(vapply(X = 1:nrow(df_epitopes),FUN = function(i) nrow(subset(df_high_confidence_epitope_metrics,(ORF==df_epitopes$Mapping_region[i])&(pos_in_protein>=df_epitopes$protein_start[i])&(pos_in_protein<=df_epitopes$protein_end[i])&(is_cross_reactive)))>=5,FUN.VALUE = c(F)))
df_epitopes$is_cross_reactive <- ifelse(test=df_epitopes$is_cross_reactive,yes="Cross-reactive",no="SC2-specific") #ifelse(test=df_epitopes$avg_pcp_conservation_score>=6,yes="Cross-reactive",no="SC2-specific")
v_position_Cross_reactive_epitopes <- NULL
for (i in 1:nrow(subset(df_epitopes,(!is.na(is_cross_reactive))&(is_cross_reactive == "Cross-reactive")))){
  v_position_Cross_reactive_epitopes <- c(v_position_Cross_reactive_epitopes,((subset(df_epitopes,(!is.na(is_cross_reactive))&(is_cross_reactive == "Cross-reactive"))$Genomic_start[i]):(subset(df_epitopes,(!is.na(is_cross_reactive))&(is_cross_reactive == "Cross-reactive"))$Genomic_End[i])))
}
v_position_Cross_reactive_epitopes<- sort(unique(v_position_Cross_reactive_epitopes))
v_position_SC2_specific_epitopes <- setdiff(v_unique_epitope_positions,v_position_Cross_reactive_epitopes)
v_length_cross_reactive_vs_sc2_specific_epitopes_positions <- c("Cross-reactive"=length(v_position_Cross_reactive_epitopes),"SC2-specific"=length(v_position_SC2_specific_epitopes))
v_coverage_cross_reactive_vs_sc2_specific_epitopes_positions <- c("Cross-reactive"=mean(subset(df_variants_NCBI_SRA_amplicon,Position%in%v_position_Cross_reactive_epitopes)$total_depth,na.rm=T),"SC2-specific"=mean(subset(df_variants_NCBI_SRA_amplicon,Position%in%v_position_SC2_specific_epitopes)$total_depth,na.rm=T))

df_variants_NCBI_SRA_amplicon$is_cross_reactive_position <- df_variants_NCBI_SRA_amplicon$Position%in%v_position_Cross_reactive_epitopes
df_variants_site_enough_covered_NCBI_SRA_amplicon <- subset(df_variants_NCBI_SRA_amplicon, total_depth>=min_cov)

#compare mutation and substitution rate cross_reactive_vs_sc2_specific epitopes
df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon <- data.frame(Sample=rep(lst_samples_NCBI_SRA_amplicon,length(c(TRUE,FALSE))),is_cross_reactive_position=rep(c(TRUE,FALSE),each=length(lst_samples_NCBI_SRA_amplicon)),nb_mutations=0,nb_fixed_mutations=0,mut_rate=0,subst_rate=0,stringsAsFactors = F)
nb_cores <- nb_cpus
lst_splits <- split(1:nrow(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon), ceiling(seq_along(1:nrow(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon))/(nrow(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon)/nb_cores)))
the_f_parallel_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon <- function(i_cl){
  the_vec<- lst_splits[[i_cl]]
  df_metrics_current_subset <- df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon[the_vec,]
  count_iter <- 0
  for (the_i in 1:nrow(df_metrics_current_subset)){
    df_depth_NCBI_SRA_amplicon_current_sample <- read.csv2(file = paste0(depth_data_wp,"depth_report_NCBI_SRA_amplicon/df_depth_NCBI_SRA_amplicon_",df_metrics_current_subset$Sample[the_i],".csv"),sep = ",",header = F,stringsAsFactors = FALSE)
    colnames(df_depth_NCBI_SRA_amplicon_current_sample) <- c("sample","position","depth")
    df_depth_NCBI_SRA_amplicon_current_sample$ORF <- vapply(X = df_depth_NCBI_SRA_amplicon_current_sample$position,FUN = find_ORF_of_mutation,FUN.VALUE = c(""))
    df_depth_NCBI_SRA_amplicon_current_sample <- unique(df_depth_NCBI_SRA_amplicon_current_sample)
    v_currentsample_positions_enough_covered <- subset(df_depth_NCBI_SRA_amplicon_current_sample,(depth>=min_cov))$position
    if (df_metrics_current_subset$is_cross_reactive_position[the_i]){
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_position_Cross_reactive_epitopes,v_currentsample_positions_enough_covered)
    }else{
      v_the_sites_with_enough_cov_for_current_category <- intersect(v_position_SC2_specific_epitopes,v_currentsample_positions_enough_covered)
    }
    df_metrics_current_subset$nb_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_fixed=="No")&(!Position%in%v_positions_inter)&(is_cross_reactive_position==df_metrics_current_subset$is_cross_reactive_position[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_fixed_mutations[the_i] <- nrow(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(is_fixed=="Yes")&(is_prevalence_above_transmission_threshold)&(is_cross_reactive_position==df_metrics_current_subset$is_cross_reactive_position[the_i])&(Sample==df_metrics_current_subset$Sample[the_i])))
    df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] <- length(v_the_sites_with_enough_cov_for_current_category)
    df_metrics_current_subset$mut_rate[the_i] <- df_metrics_current_subset$nb_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$subst_rate[the_i] <- df_metrics_current_subset$nb_fixed_mutations[the_i]/df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i]
    df_metrics_current_subset$Nb_ss[the_i] <- sum(unname(vapply(X = v_the_sites_with_enough_cov_for_current_category,FUN = calculate_nb_ss_position_in_genome,FUN.VALUE = c(0))),na.rm=T)
    df_metrics_current_subset$Nb_nss[the_i] <- df_metrics_current_subset$nb_sites_with_enough_cov_for_this_category[the_i] - df_metrics_current_subset$Nb_ss[the_i]
    df_metrics_current_subset$within_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$within_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(!Position%in%v_positions_inter)&(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq<0.75)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_nsm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(!(is_synonymous))&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_nonsynonymous_mutations_NCBI_SRA_amplicon))
    df_metrics_current_subset$between_host_Nb_sm[the_i] <- length(intersect(subset(df_variants_site_enough_covered_NCBI_SRA_amplicon,(Position %in% v_the_sites_with_enough_cov_for_current_category)&(!is.na(is_synonymous))&(is_synonymous)&(VarFreq>=0.75)&(is_prevalence_above_transmission_threshold)&(Sample==df_metrics_current_subset$Sample[the_i]))$mutation_name,v_lst_synonymous_mutations_NCBI_SRA_amplicon))

    if (the_i%%100==0){
      print(paste0("[Cross-reactive vs SC2-secific epitopes (NCBI)] Core ",i_cl,": Step ",the_i," done out of ",nrow(df_metrics_current_subset),"!"))
    }
  }
  df_metrics_current_subset$pN <- df_metrics_current_subset$within_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$pS <- df_metrics_current_subset$within_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$pN_pS <- ifelse(test=df_metrics_current_subset$pS==0,yes=NA,no=df_metrics_current_subset$pN/df_metrics_current_subset$pS)
  df_metrics_current_subset$dN <- df_metrics_current_subset$between_host_Nb_nsm/df_metrics_current_subset$Nb_nss
  df_metrics_current_subset$dS <- df_metrics_current_subset$between_host_Nb_sm/df_metrics_current_subset$Nb_ss
  df_metrics_current_subset$dN_dS <- ifelse(test=df_metrics_current_subset$dS==0,yes=NA,no=df_metrics_current_subset$dN/df_metrics_current_subset$dS)
  df_metrics_current_subset$alpha_MK_Test <- ifelse(test=df_metrics_current_subset$dN_dS==0,yes=NA,no=(1-((df_metrics_current_subset$pN_pS)/(df_metrics_current_subset$dN_dS))))

  return(df_metrics_current_subset)
}
cl <- makeCluster(nb_cores,outfile=paste0(output_workspace,"LOG_Evo_rates_analyses.txt"))
registerDoParallel(cl)
df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon <- foreach(i_cl = 1:nb_cores, .combine = rbind, .packages=c("ggplot2","seqinr","grid","RColorBrewer","randomcoloR","gplots","RColorBrewer","tidyr","infotheo","parallel","foreach","doParallel","Biostrings"))  %dopar% the_f_parallel_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon(i_cl)
stopCluster(cl)
saveRDS(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon,paste0(output_workspace,"df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon.rds"))

ggplot(data = df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_cross_reactive_position),levels=c("TRUE","FALSE")),y = mut_rate,fill=as.character(is_cross_reactive_position))) + geom_violin() + geom_point() + xlab("Cross-reactive epitope sites?") + ylab("Within-host mutation rate (Count / Length)") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + scale_y_continuous(breaks=seq(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$mut_rate)+1e-2,1e-2),limits = c(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$mut_rate)+1e-2)) + stat_compare_means(method = "wilcox")
ggsave(filename = "Mutation_rate_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
ggplot(data = df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_cross_reactive_position),levels=c("TRUE","FALSE")),y = subst_rate,fill=as.character(is_cross_reactive_position))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("Cross-reactive epitope sites?") + ylab("Substitution rate (Count / Length)") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_y_continuous(breaks=seq(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$subst_rate)+1e-4,1e-4),limits = c(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$subst_rate)+1e-4)) + stat_compare_means(method = "wilcox")
ggsave(filename = "Substitution_rate_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)

ggplot(data = df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_cross_reactive_position),levels=c("TRUE","FALSE")),y = pN_pS,fill=as.character(is_cross_reactive_position))) + geom_violin() + geom_point() + xlab("Cross-reactive epitope sites?") + ylab("pN/pS") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + stat_compare_means(method = "wilcox") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$pN_pS)+1e-2,1e-2),limits = c(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$pN_pS)+1e-2))
ggsave(filename = "pN_pS_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
ggplot(data = df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_cross_reactive_position),levels=c("TRUE","FALSE")),y = dN_dS,fill=as.character(is_cross_reactive_position))) + geom_violin() + geom_boxplot(width=0.075,fill="white") + geom_point() + xlab("Cross-reactive epitope sites?") + ylab("dN/dS") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + stat_compare_means(method = "wilcox") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$dN_dS)+1e-4,1e-4),limits = c(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$dN_dS)+1e-4))
ggsave(filename = "dN_dS_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)
ggplot(data = df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon,aes(x=factor(as.character(is_cross_reactive_position),levels=c("TRUE","FALSE")),y = alpha_MK_Test,fill=as.character(is_cross_reactive_position))) + geom_violin() + geom_point() + xlab("Cross-reactive epitope sites?") + ylab("McDonald-Kreitman test \U003B1") + theme(axis.title = element_text(size=12),axis.text = element_text(size=12),legend.position = "none") + scale_fill_manual(values = c("TRUE"="tan2","FALSE"="grey60")) + stat_compare_means(method = "wilcox") #+ scale_y_continuous(breaks=seq(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$alpha_MK_Test)+1e-2,1e-2),limits = c(0,max(df_metrics_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon$alpha_MK_Test)+1e-2))
ggsave(filename = "MK_test_alpha_cross_reactive_vs_sc2_specific_epitopes_NCBI_SRA_amplicon.png", path=output_workspace, width = 15, height = 15, units = "cm",dpi = 1200)

#Proportion of epitope sites with mutation
proportion_epitope_sites_with_mutation_NCBI_SRA_amplicon <- length(unique(subset(df_variants_NCBI_SRA_amplicon,is_epitope_related)$Position))/length(v_unique_epitope_positions)

#add SNVs position in ORF protein
df_variants_NCBI_SRA_amplicon$pos_in_ORF_protein_seq <- vapply(X = 1:nrow(df_variants_NCBI_SRA_amplicon),FUN = function(i) ceiling((df_variants_NCBI_SRA_amplicon$Position[i] - v_start_orfs[df_variants_NCBI_SRA_amplicon$ORF[i]] + 1)/3),FUN.VALUE = c(0))

#EhCoVs prevalence
df_epitopes_HKU1$protein_start <- unname(ceiling((df_epitopes_HKU1$Genomic_start - v_start_orfs[as.character(df_epitopes_HKU1$Mapping_region)] + 1)/3))
df_epitopes_HKU1$protein_end <- unname(ceiling((df_epitopes_HKU1$Genomic_End - v_start_orfs[as.character(df_epitopes_HKU1$Mapping_region)] + 1)/3))
df_epitopes_NL63$protein_start <- unname(ceiling((df_epitopes_NL63$Genomic_start - v_start_orfs[as.character(df_epitopes_NL63$Mapping_region)] + 1)/3))
df_epitopes_NL63$protein_end <- unname(ceiling((df_epitopes_NL63$Genomic_End - v_start_orfs[as.character(df_epitopes_NL63$Mapping_region)] + 1)/3))
df_epitopes_OC43$protein_start <- unname(ceiling((df_epitopes_OC43$Genomic_start - v_start_orfs[as.character(df_epitopes_OC43$Mapping_region)] + 1)/3))
df_epitopes_OC43$protein_end <- unname(ceiling((df_epitopes_OC43$Genomic_End - v_start_orfs[as.character(df_epitopes_OC43$Mapping_region)] + 1)/3))
df_epitopes_229E$protein_start <- unname(ceiling((df_epitopes_229E$Genomic_start - v_start_orfs[as.character(df_epitopes_229E$Mapping_region)] + 1)/3))
df_epitopes_229E$protein_end <- unname(ceiling((df_epitopes_229E$Genomic_End - v_start_orfs[as.character(df_epitopes_229E$Mapping_region)] + 1)/3))

#Positive vs negative patients RFU boxplots
df_epitopes$pos_neg <- v_patients_to_binary_group[df_epitopes$patient_ID]

#cross-reactive epitopes definition
df_epitopes$is_cross_reactive <- unname(vapply(X = 1:nrow(df_epitopes),FUN = function(i) nrow(subset(df_high_confidence_epitope_metrics,(ORF==df_epitopes$Mapping_region[i])&(pos_in_protein>=df_epitopes$protein_start[i])&(pos_in_protein<=df_epitopes$protein_end[i])&(is_cross_reactive)))>=5,FUN.VALUE = c(F)))
df_proteins_nb_cr_and_SC2_specific_epitopes_current_study <- data.frame(ORF=c("orf1a","orf1b","S","E","M","N"), Number_of_cross_reactive_epitopes = NA, Number_of_SC2_specific_epitopes = NA)
df_proteins_nb_cr_and_SC2_specific_epitopes_current_study$Number_of_cross_reactive_epitopes <- unname(vapply(X = c("orf1a","orf1b","S","E","M","N"),FUN=function(x) nrow(subset(df_epitopes,(Mapping_region==x)&(is_cross_reactive))),FUN.VALUE = c(0)))
df_proteins_nb_cr_and_SC2_specific_epitopes_current_study$Number_of_SC2_specific_epitopes <- unname(vapply(X = c("orf1a","orf1b","S","E","M","N"),FUN=function(x) nrow(subset(df_epitopes,(Mapping_region==x)&(!is_cross_reactive))),FUN.VALUE = c(0)))
df_epitopes$is_cross_reactive <- ifelse(test=df_epitopes$is_cross_reactive,yes="Cross-reactive",no="SC2-specific") #ifelse(test=df_epitopes$avg_pcp_conservation_score>=6,yes="Cross-reactive",no="SC2-specific")
#write.table(x=df_proteins_nb_cr_and_SC2_specific_epitopes_current_study,file = paste0(output_workspace,"Table_number_of_cross_reactive_and_sc2_specific_epitopes_current_study.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)

#effect of threshold nb cross-reactive epitope sites on the number of cross-reactive epitopes (sensitivity analysis)
df_nb_cr_epitopes <- NULL
df_slope_correlation_avg_immune_resp_vs_nb_cr_epitopes_current_study <- NULL
for (n in 1:15){
  df_epitopes$is_cross_reactive <- unname(vapply(X = 1:nrow(df_epitopes),FUN = function(i) nrow(subset(df_high_confidence_epitope_metrics,(ORF==df_epitopes$Mapping_region[i])&(pos_in_protein>=df_epitopes$protein_start[i])&(pos_in_protein<=df_epitopes$protein_end[i])&(is_cross_reactive)))>=n,FUN.VALUE = c(F)))
  current_fit_avg_immune_resp_vs_nb_epitopes <- lm(formula = scale(df_avg_immune_responses_sc2_vs_ehcovs$avg_sc2_RFU,T,T)~scale(unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(is_cross_reactive))$peptide_id)),FUN.VALUE = c(0))),T,T))
  df_nb_cr_epitopes <- rbind(df_nb_cr_epitopes,data.frame(dataset="Current study",threshold_nb_cr_sites=n,Sample=df_avg_immune_responses_sc2_vs_ehcovs$patient,nb_cr_epitopes=unname(vapply(X = df_avg_immune_responses_sc2_vs_ehcovs$patient,FUN = function(x) length(unique(subset(df_epitopes,(patient_ID==x)&(is_cross_reactive))$peptide_id)),FUN.VALUE = c(0))),stringsAsFactors = F))
  df_slope_correlation_avg_immune_resp_vs_nb_cr_epitopes_current_study <- rbind(df_slope_correlation_avg_immune_resp_vs_nb_cr_epitopes_current_study,data.frame(dataset="Current study",threshold_nb_cr_sites=n,slope=ifelse(test=broom::glance(current_fit_avg_immune_resp_vs_nb_epitopes)$p.value<0.05,yes = unname(coefficients(current_fit_avg_immune_resp_vs_nb_epitopes)[2]),no=NA),stringsAsFactors = F))
}
#write.table(x=df_nb_cr_epitopes,file = paste0(output_workspace,"Table_nb_x_reactive_epitopes_per_patient_current_study.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)
#saveRDS(object = df_nb_cr_epitopes,file = paste0(output_workspace,"Table_nb_x_reactive_epitopes_per_patient_current_study.rds"))
#write.table(x=df_slope_correlation_avg_immune_resp_vs_nb_cr_epitopes_current_study,file = paste0(output_workspace,"Table_avg_immune_resp_vs_nb_cr_epitopes_current_study.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)
#saveRDS(object = df_slope_correlation_avg_immune_resp_vs_nb_cr_epitopes_current_study,file = paste0(output_workspace,"Table_avg_immune_resp_vs_nb_cr_epitopes_current_study.rds"))

df_epitopes$is_cross_reactive <- unname(vapply(X = 1:nrow(df_epitopes),FUN = function(i) nrow(subset(df_high_confidence_epitope_metrics,(ORF==df_epitopes$Mapping_region[i])&(pos_in_protein>=df_epitopes$protein_start[i])&(pos_in_protein<=df_epitopes$protein_end[i])&(is_cross_reactive)))>=5,FUN.VALUE = c(F)))
df_epitopes$is_cross_reactive <- ifelse(test=df_epitopes$is_cross_reactive,yes="Cross-reactive",no="SC2-specific") #ifelse(test=df_epitopes$avg_pcp_conservation_score>=6,yes="Cross-reactive",no="SC2-specific")


# ##########################Mutations of interest####################

#mutation emergence (which wave)
df_variants_NCBI_SRA_amplicon$wave <- ifelse(is.na(df_variants_NCBI_SRA_amplicon$collection_date),yes=NA,no=ifelse(test=df_variants_NCBI_SRA_amplicon$collection_date < "2020-07",yes=1,no=ifelse(test=df_variants_NCBI_SRA_amplicon$collection_date < "2021-03",yes=2,no=3)))
df_variants_NCBI_SRA_amplicon$short_label_mut <- paste0(df_variants_NCBI_SRA_amplicon$gene,":",df_variants_NCBI_SRA_amplicon$old_aa,df_variants_NCBI_SRA_amplicon$pos_in_protein,df_variants_NCBI_SRA_amplicon$new_aa)
v_lst_short_label_mut_NCBI_SRA_amplicon <- sort(unique(df_variants_NCBI_SRA_amplicon$short_label_mut))
v_wave_of_emergence_of_mutations_NCBI_SRA_amplicon <- vapply(X = v_lst_short_label_mut_NCBI_SRA_amplicon, FUN = function(the_mut) ifelse(all(is.na(subset(df_variants_NCBI_SRA_amplicon,short_label_mut==the_mut)$collection_date)),yes=NA,no=min(subset(df_variants_NCBI_SRA_amplicon,short_label_mut==the_mut)$wave,na.rm=T)),FUN.VALUE = c(0))
v_prevalence_mutations <- vapply(X = v_lst_short_label_mut_NCBI_SRA_amplicon, FUN = function(the_mut) length(unique(subset(df_variants_NCBI_SRA_amplicon,short_label_mut==the_mut)$Sample)),FUN.VALUE = c(0))

#S protein mutations of concern or under investigation
v_S_region_mutations_of_interest_in_epitope_sites <- intersect(paste0("S:",v_S_region_mutations_of_interest),subset(df_variants_NCBI_SRA_amplicon,is_epitope_related)$short_label_mut)
df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon <- data.frame(mutation=unique(v_S_region_mutations_of_interest_in_epitope_sites),prevalence_mutation=v_prevalence_mutations[v_S_region_mutations_of_interest_in_epitope_sites],Wave_first_time_observed=v_wave_of_emergence_of_mutations_NCBI_SRA_amplicon[v_S_region_mutations_of_interest_in_epitope_sites],avg_RFU=NA,avg_RFU_epitope_site_in_positive_patients_current_study=NA,avg_RFU_epitope_site_in_negative_patients_current_study=NA,is_detected_as_cross_reactive_in_current_study=NA,prevalence_epitope_site_in_positive_patients_current_study=NA,prevalence_epitope_site_in_negative_patients_current_study=NA,month_first_time_detected=NA,lst_candidate_country_first_apparition=NA,stringsAsFactors = F)
for (i in 1:nrow(df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon)){
  pos_in_S_current_mut <- as.integer(substr(df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$mutation[i],gregexpr(pattern = ":",text = df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$mutation[i],fixed=T)[[1]][1]+2,nchar(df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$mutation[i])-1))
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$avg_RFU[i] <- mean(subset(df_epitopes,(!is.na(Mapping_region))&(Mapping_region=="S")&(pos_in_S_current_mut>=protein_start)&(pos_in_S_current_mut<=protein_end))$RFU, na.rm=T)
  
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$prevalence_epitope_site_in_positive_patients_current_study[i] <- ifelse(nrow(subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut)))>0,subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut))$prevalence_in_positive_patients,0)
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$prevalence_epitope_site_in_negative_patients_current_study[i] <- ifelse(nrow(subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut)))>0,subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut))$prevalence_in_negative_patients,0)
  if (df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$prevalence_epitope_site_in_positive_patients_current_study[i]>0){
    df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$avg_RFU_epitope_site_in_positive_patients_current_study[i] <- subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut))$avg_RFU_in_positive_patients
  }
  if (df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$prevalence_epitope_site_in_negative_patients_current_study[i]>0){
    df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$avg_RFU_epitope_site_in_negative_patients_current_study[i] <- subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut))$avg_RFU_in_negative_patients
  }
  v <- subset(df_high_confidence_epitope_metrics,(ORF=="S")&(pos_in_protein==pos_in_S_current_mut))$is_cross_reactive
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$is_detected_as_cross_reactive_in_current_study[i] <- ifelse(length(v)>0,v,FALSE)
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$month_first_time_detected[i] <- min(subset(df_variants_NCBI_SRA_amplicon,short_label_mut==df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$mutation[i])$collection_date,na.rm=T)
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$month_first_time_detected[i] <- ifelse(df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$month_first_time_detected[i]==Inf,yes=NA,no=df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$month_first_time_detected[i])
  df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$lst_candidate_country_first_apparition[i] <- paste0(names(table(subset(df_variants_NCBI_SRA_amplicon,(short_label_mut==df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$mutation[i])&(collection_date==df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$month_first_time_detected[i]))$seq_country)),collapse="/")

}
#measure difference in avg_RFU between Covid19- and Covid19+
df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$Difference_avg_RFU_epitope_sites_neg_vs_pos_patients_current_study <- df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$avg_RFU_epitope_site_in_negative_patients_current_study - df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon$avg_RFU_epitope_site_in_positive_patients_current_study
write.table(x=df_metrics_S_region_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon,file = paste0(output_workspace,"Table_metrics_S_protein_mutations_of_interest_in_epitopes_NCBI_SRA_amplicon.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)

#list of non-synonymous mutations
v_lst_ns_mut <- sort(unique(subset(df_variants_NCBI_SRA_amplicon,(!is.na(mutation_type))&(mutation_type=="Non-Synonymous"))$mutation_name))

#metrics_ALL_MISSENSE_mutations_sites (only select N-S mutations in epitope sites)
df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon <- data.frame(mutation=unique(subset(df_variants_NCBI_SRA_amplicon,(mutation_type=="Non-Synonymous")&(is_epitope_related))$mutation_name),complete_mut_name=NA,protein=NA,pos_in_prot=NA,avg_RFU=NA,prevalence_mutation=NA,Wave_first_time_observed=NA,avg_RFU_epitope_site_in_positive_patients_current_study=NA,avg_RFU_epitope_site_in_negative_patients_current_study=NA,is_detected_as_cross_reactive_in_current_study=NA,prevalence_epitope_site_in_positive_patients_current_study=NA,prevalence_epitope_site_in_negative_patients_current_study=NA,month_first_time_detected=NA,lst_candidate_country_first_apparition=NA,stringsAsFactors = F)
for (i in 1:nrow(df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon)){
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$complete_mut_name[i] <- df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i]
  current_mut_short_label <- subset(df_variants_NCBI_SRA_amplicon,mutation_name==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i])$short_label_mut[1]
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i] <- subset(df_variants_NCBI_SRA_amplicon,mutation_name==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i])$ORF[1]
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i] <- subset(df_variants_NCBI_SRA_amplicon,mutation_name==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i])$pos_in_ORF_protein_seq[1]
  #pos_in_prot in actually pos_in_ORF from last line
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$avg_RFU[i] <- mean(subset(df_epitopes,(!is.na(Mapping_region))&(Mapping_region==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]>=protein_start)&(df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]<=protein_end))$RFU, na.rm=T)
  #mutation name becomes mut_short_label from here on
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i] <- current_mut_short_label

  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$prevalence_mutation[i] <- v_prevalence_mutations[current_mut_short_label]
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$Wave_first_time_observed[i] <- v_wave_of_emergence_of_mutations_NCBI_SRA_amplicon[current_mut_short_label]

  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$prevalence_epitope_site_in_positive_patients_current_study[i] <- ifelse(nrow(subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i])))>0,subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]))$prevalence_in_positive_patients,0)
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$prevalence_epitope_site_in_negative_patients_current_study[i] <- ifelse(nrow(subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i])))>0,subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]))$prevalence_in_negative_patients,0)

  if (df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$prevalence_epitope_site_in_positive_patients_current_study[i]>0){
    df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$avg_RFU_epitope_site_in_positive_patients_current_study[i] <- subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]))$avg_RFU_in_positive_patients
  }
  if (df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$prevalence_epitope_site_in_negative_patients_current_study[i]>0){
    df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$avg_RFU_epitope_site_in_negative_patients_current_study[i] <- subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]))$avg_RFU_in_negative_patients
  }

  v <- subset(df_high_confidence_epitope_metrics,(ORF==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$protein[i])&(pos_in_protein==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$pos_in_prot[i]))$is_cross_reactive
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$is_detected_as_cross_reactive_in_current_study[i] <- ifelse(length(v)>0,v,FALSE)

  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$month_first_time_detected[i] <- min(subset(df_variants_NCBI_SRA_amplicon,short_label_mut==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i])$collection_date,na.rm=T)
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$month_first_time_detected[i] <- ifelse(df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$month_first_time_detected[i]==Inf,yes=NA,no=df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$month_first_time_detected[i])
  df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$lst_candidate_country_first_apparition[i] <- paste0(names(table(subset(df_variants_NCBI_SRA_amplicon,(short_label_mut==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$mutation[i])&(collection_date==df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$month_first_time_detected[i]))$seq_country)),collapse="/")

}

#number of samples
nb_samples_NCBI_SRA_amplicon <- length(unique(df_variants_NCBI_SRA_amplicon$Sample))

#ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon 
df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$label_wave <- paste0("Wave ",df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon$Wave_first_time_observed)
write.table(x=df_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon,file = paste0(output_workspace,"Table_immunological_metrics_ALL_MISSENSE_mutations_sites_NCBI_SRA_amlicon.csv"),sep = ",",na = "NA",row.names = FALSE,col.names = TRUE)

#save Rsession
library("session")
save.session(file = paste0(output_workspace,"SECOND_WAVE_high_confidence_epitope_analysis_RSession.Rda"))
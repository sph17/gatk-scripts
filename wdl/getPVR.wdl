version 1.0

import "Structs.wdl"

workflow getPVR {

  #################################################################################
  ####        Required basic arguments 						                      #
  ####  docker: us.gcr.io/talkowski-sv-gnomad/get-pvr:version1					  #
  #################################################################################
    
  input {
    File indel_file
    File trio_list
    File mother_cram
    File mother_crai
    File father_cram
    File father_crai
    File proband_cram
    File proband_crai
    File? additional_cram_1
    File? additional_crai_1
    File? additional_cram_2
    File? additional_crai_2
    File? additional_cram_3
    File? additional_crai_3
    File? additional_cram_4
    File? additional_crai_4
    File? additional_cram_5
    File? additional_crai_5
    File? additional_cram_6
    File? additional_crai_6
    String pvr_docker
    String fam_members

    # Runtime configuration overrides
    RuntimeAttr? runtime_attr_getPVR

  }

  meta {
    author: "Stephanie Hao"
    email: "shao@broadinstitute.org"
  }
    
  #################################################################################
  ####        Calculate de novo PVR script	                                      #
  #################################################################################
  
  call calculatePVR as pvr {
    input :
      indel_file = indel_file,
      trio_list = trio_list,
      mother_cram = mother_cram,
      mother_crai = mother_crai,
      father_cram = father_cram,
      father_crai = father_crai,
      proband_cram = proband_cram,
      proband_crai = proband_crai,
      pvr_docker = pvr_docker,
      fam_members = fam_members,
      additional_cram_1 = additional_cram_1,
      additional_crai_1 = additional_crai_1,
      additional_cram_2 = additional_cram_2,
      additional_crai_2 = additional_crai_2, 
      additional_cram_3 = additional_cram_3,
      additional_crai_3 = additional_crai_3, 
      additional_cram_4 = additional_cram_4,
      additional_crai_4 = additional_crai_4,
      additional_cram_5 = additional_cram_5,
      additional_crai_5 = additional_crai_5,
      additional_cram_6 = additional_cram_6,
      additional_crai_6 = additional_crai_6,
      runtime_attr_override = runtime_attr_getPVR
  }


  output {
    File pvr_file = pvr.getPVR_out
    File failed_file = pvr.redo
  }
}



task calculatePVR {
  input {
    File indel_file
    File trio_list
    File mother_cram
    File mother_crai
    File father_cram
    File father_crai
    File proband_cram
    File proband_crai
    File? additional_cram_1
    File? additional_crai_1
    File? additional_cram_2
    File? additional_crai_2
    File? additional_cram_3
    File? additional_crai_3
    File? additional_cram_4
    File? additional_crai_4
    File? additional_cram_5
    File? additional_crai_5
    File? additional_cram_6
    File? additional_crai_6
    String pvr_docker
    String fam_members
    RuntimeAttr? runtime_attr_override
  }

  # Runtime parameters adapted from gatk-sv "CollectCoverage.wdl"
  Int num_cpu = 4
  Int mem_size_gb = 16
  Int vm_disk_size = 300

  RuntimeAttr default_attr = object {
    cpu_cores: num_cpu,
    mem_gb: mem_size_gb, 
    disk_gb: vm_disk_size,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }

  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])



  String fam_id = basename(indel_file, ".txt")
  String pvr_filename = "${fam_id}_with_PVR.txt"
  String pvr_redo = "${fam_id}_redo.txt"
  
  String cram_dir = "/cromwell_root/fc-5e80ede2-9204-4178-ba7a-10d58a9fd229/mssng/crams/"

    
  command <<<
    set -euo pipefail
    
    perl /home/get_pvr_from_crams_wdl.pl -i ~{indel_file} -b "~{fam_members}" -m ~{trio_list}

  >>>

  runtime {
    docker: pvr_docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

  output {
    File getPVR_out = pvr_filename
    File redo = pvr_redo
  }
}
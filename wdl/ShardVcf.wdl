version 1.0

import "Structs.wdl"

workflow ShardVcf {
  input {
    File vcf
    String prefix
    Int records_per_shard
    Int? threads = 1
    String sv_pipeline_docker
    RuntimeAttr? runtime_attr_scatter_override
  }

call ScatterVcf {
  input:
    vcf=vcf,
    records_per_shard=records_per_shard,
    threads=threads,
    sv_pipeline_docker=sv_pipeline_docker,
    runtime_attr_override=runtime_attr_scatter_override
  }

output {
  Array[File] vcf_shards = ScatterVcf.shards
}
}


# Note: requires docker with updated bcftools
task ScatterVcf {
  input {
    File vcf
    String prefix
    Int records_per_shard
    Int? threads = 1
    String sv_pipeline_docker
    RuntimeAttr? runtime_attr_override
  }

  Float input_size = size(vcf, "GB")
  Float base_disk_gb = 10.0

  RuntimeAttr runtime_default = object {
                                  mem_gb: 3.75,
                                  disk_gb: ceil(base_disk_gb + input_size * 5.0),
                                  cpu_cores: 2,
                                  preemptible_tries: 3,
                                  max_retries: 1,
                                  boot_disk_gb: 10
                                }
  RuntimeAttr runtime_override = select_first([runtime_attr_override, runtime_default])
  runtime {
    memory: "~{select_first([runtime_override.mem_gb, runtime_default.mem_gb])} GB"
    disks: "local-disk ~{select_first([runtime_override.disk_gb, runtime_default.disk_gb])} HDD"
    cpu: select_first([runtime_override.cpu_cores, runtime_default.cpu_cores])
    preemptible: select_first([runtime_override.preemptible_tries, runtime_default.preemptible_tries])
    maxRetries: select_first([runtime_override.max_retries, runtime_default.max_retries])
    docker: sv_pipeline_docker
    bootDiskSizeGb: select_first([runtime_override.boot_disk_gb, runtime_default.boot_disk_gb])
  }

  command <<<
    set -euo pipefail
    # in case the file is empty create an empty shard
    bcftools view -h ~{vcf} | bgzip -c > ~{prefix}.0.vcf.gz
    bcftools +scatter ~{vcf} -o . -O z -p ~{prefix}. --threads ~{threads} -n ~{records_per_shard}

    ls ~{prefix}.*.vcf.gz | sort -k1,1V > vcfs.list
    i=0
    while read vcf; do
      shard_no=`printf %06d $i`
      mv ${vcf} ~{prefix}.shard_${shard_no}.vcf.gz
      i=$((i+1))
    done < vcfs.list
  >>>
  output {
    Array[File] shards = glob("~{prefix}.shard_*.vcf.gz")
  }
}


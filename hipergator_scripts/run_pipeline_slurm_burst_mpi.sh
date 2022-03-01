#!/bin/bash
#SBATCH --job-name=run_pipeline_mpi      # Job name
#SBATCH --mail-type=NONE          # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=adamginsburg@ufl.edu     # Where to send mail
#SBATCH --ntasks=32                     # 
#SBATCH --mem=128gb                     # Job memory request
#SBATCH --time=96:00:00               # Time limit hrs:min:sec
#SBATCH --output=run_pipeline_mpi_%j.log   # Standard output and error log
#SBATCH --qos=adamginsburg-b
#SBATCH --account=adamginsburg

env
pwd; hostname; date
echo "Memory=${MEM}"

module load cuda/11.0.207
module load intel/2012.0.166
module load openmpi/4.0.4 
module load libfuse/3.10.4

LOG_DIR=/blue/adamginsburg/adamginsburg/ACES/logs
export LOGFILENAME="${LOG_DIR}/casa_log_mpi_pipeline_${SLURM_JOB_ID}_$(date +%Y-%m-%d_%H_%M_%S).log"

WORK_DIR='/orange/adamginsburg/ACES/rawdata/2021.1.00172.L'
cd ${WORK_DIR}
# this directory should contain a folder pipeline_scripts/ if any overloaded pipeline scripts are expected
export ACES_ROOTDIR="/orange/adamginsburg/ACES/reduction_ACES/"

CASAVERSION=casa-6.2.1-7-pipeline-2021.2.0.128
export MPICASA=/orange/adamginsburg/casa/${CASAVERSION}/bin/mpicasa
export MPICASA=$(realpath ${MPICASA})
export CASA=/orange/adamginsburg/casa/${CASAVERSION}/bin/casa
export CASA=$(realpath ${CASA})
casapython=$(realpath /orange/adamginsburg/casa/${CASAVERSION}/lib/py/bin/python3)

export OMPI_COMM_WORLD_SIZE=$SLURM_NTASKS

# since we're bursting, be careful not to partially start a pipeline run
#export RUNONCE=True

# echo xvfb-run -d ${MPICASA} -n 8 ${CASA} --logfile=${LOGFILENAME} --pipeline --nogui --nologger -c "execfile('${ACES_ROOTDIR}/retrieval_scripts/run_pipeline.py')"
# xvfb-run -d ${MPICASA} -n ${SLURM_NTASKS} ${CASA} --logfile=${LOGFILENAME} --pipeline --nogui --nologger -c "execfile('${ACES_ROOTDIR}/retrieval_scripts/run_pipeline.py')" &
#echo ${CASA} --logfile=${LOGFILENAME} --pipeline --nogui --nologger -c "execfile('${ACES_ROOTDIR}/retrieval_scripts/run_pipeline.py')"
echo ${MPICASA} -n ${SLURM_NTASKS} ${CASA} --logfile=${LOGFILENAME} --pipeline --nogui --nologger -c "execfile('${ACES_ROOTDIR}/retrieval_scripts/run_pipeline.py')" &
${MPICASA} -n ${SLURM_NTASKS} ${CASA} --logfile=${LOGFILENAME} --pipeline --nogui --nologger --ipython-dir=/tmp -c "execfile('${ACES_ROOTDIR}/retrieval_scripts/run_pipeline.py')" &
ppid="$!"; childPID="$(ps -C ${CASA} -o ppid,pid | awk -v ppid="$ppid" '$1==ppid {print $2}')"
echo PID=${ppid} childPID=${childPID}

if [[ ! -z $childPID ]]; then 
    # /orange/adamginsburg/miniconda3/bin/python ${ALMAIMF_ROOTDIR}/slurm_scripts/monitor_memory.py ${childPID}
    echo PID=${childPID}
else
    childPID="$(ps -C ${casapython} -o ppid,pid | awk -v ppid="$ppid" '$1==ppid {print $2}')"
    if [[ ! -z $childPID ]]; then
        echo PID=${childPID}
    else
        echo "FAILURE: PID=$PID was not set."
    fi
fi

echo "Waiting on $ppid: $(ps -o ppid,pid,cmd | grep $ppid)"
wait $ppid
exitcode=$?

cd -

exit $exitcode

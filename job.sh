#!/bin/bash
#SBATCH --job-name=exp01           # Job name
#SBATCH --nodes=1        
#SBATCH --nodelist=damnii02                # Number of nodes
#SBATCH --gres=gpu:8             # Number of GPUs required
#SBATCH --partition=PGR-Standard
#SBATCH --time=2-00:00:00              # Walltime

rats/vscode --jumpserver s2514643@daisy2.inf.ed.ac.uk --port 4062

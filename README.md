# Company-specific transition risks in the global power sector

This repository contains scripts and a subset of data used in the manuscript: "Company-specific transition risks in the global power sector."

## System Requirements

### Tested on:
- **MATLAB Versions:** R2023a, R2022a, R2021a/b
- **Operating System:** MacOS Ventura 13.4.1

### Software:
- MATLAB is compatible with major platforms: Linux, MacOS, and Windows.
- Required Toolboxes: 
  - Statistics and Machine Learning (v12.5)
  - Optimization (v9.5)
  - Global Optimization (v4.8.1)

 ### Hardware:
- **Processor:** Matlab requires any Intel or AMD x86-64 processor with a minimum of two cores.
- **RAM:** Minimum: 8 GB; Recommended: 16 GB.
- **Storage:** Matlab requires 4 - 6 GB for basic installation; Toolboxes will require additional hard drive space.

## Installation Guide

### Instructions:
1. Install MATLAB on your system.
2. Download and install the required MATLAB Toolboxes with the specified versions.
3. Clone this repository or download the necessary files and data.

### Typical Install Time:
- MATLAB and Toolboxes: Varies based on internet and computer speed, typically around 30-60 minutes.

## Model demo

### Instructions:
1. Run preprocessing scripts in the order specified at the end of their names.
2. Execute figure-related scripts in any desired order after completing preprocessing.

### Expected Output:
1. Figure files will perform calculations and produce at least panel a from the figure they are named after. 

### Expected Run Time for Demo:
- Preprocessing 1: Varies based on the computer and power plant fuel type being analyzed, typically around 5 minutes
- Preprocessing 2: Varies based on the computer and power plant fuel but can be up to 15 minutes.
- Generating Figures: Most figure files should take 5 minutes or less to run. Please note the Figure 1 file will take slightly longer than 5 minutes, and the Figure 4 file will take around 10 to 20 minutes to complete. 

## Instructions for Use

### Running the power plant transition risks model:
1. Ensure the data directory is correct in the source code once data has been retrieved. Otherwise, modify the file paths accordingly.
2. Data subset is located at https://github.com/rfofrich/Power_sector_transition_risks/tree/main/Data. The remaining data can be made available upon reasonable request.
3. Follow the steps mentioned in the demo section to execute the code with your data.

### Reproduction 

The source code should reproduce the quantitative results presented in the manuscript if the scripts are run in the correct order. The source data can be found within the links provided in the manuscript. Please reach out to the corresponding authors if you are having trouble with any sections of the code or if any inconsistencies are found.

## License

This project is released under the MIT License.

For further inquiries or reproduction assistance, contact Dr. Robert Fofrich Navarro at robertfofrich@ucla.edu.

# amstaR-ai: Reproducible Systematic Review Screening

A production-ready R tool for automated AMSTAR2 quality assessment of systematic reviews using dual AI evaluation. Designed for academic researchers requiring reproducible, scalable screening processes.

## Overview

**amstaR-ai** provides automated quality assessment of systematic reviews using the validated AMSTAR2 framework. The tool employs two independent AI judges (Anthropic Claude and OpenAI GPT) to ensure robust evaluation and reduce individual model bias.

### Key Features

- **Dual AI Evaluation**: Independent assessment by Claude Sonnet 4 and GPT-4o-mini
- **Production-Ready**: Robust error handling, automatic retries, and checkpoint recovery
- **Reproducible Process**: Standardized AMSTAR2 implementation with detailed logging
- **Scalable**: Parallel processing with efficient file management
- **Quality Control**: Structured output for inter-rater reliability analysis

## Scientific Rationale

This tool addresses the time-intensive nature of AMSTAR2 evaluations in large-scale evidence synthesis projects. By implementing dual AI assessment, researchers can:

1. **Accelerate screening** while maintaining methodological rigor
2. **Reduce human bias** through standardized evaluation criteria
3. **Enable large-scale studies** that would be impractical with manual assessment alone
4. **Maintain transparency** with detailed evaluation justifications

## Installation

### Prerequisites

```r
# Required R packages
install.packages(c("httr2", "jsonlite", "future", "future.apply"))
```

### API Configuration

Create a `.Renviron` file in your project root:

```bash
ANTHROPIC_API_KEY=sk-ant-api03-...
OPENAI_API_KEY=sk-proj-...
```

### Directory Structure

```
amstaR-ai/
├── amstaR-ai.R
├── data/
│   └── articles/          # Place PDF files here
├── results/               # Auto-created for outputs
├── .Renviron             # API keys
└── README.md
```

## Usage

### Basic Execution

```bash
Rscript amstaR-ai.R
```

### From R Console

```r
source("amstaR-ai.R")
results <- main()
```

## Input Requirements

- **Format**: PDF files of systematic reviews
- **Location**: `data/articles/` directory
- **Content**: Systematic reviews with or without meta-analyses
- **Language**: English (optimized for English-language reviews)

## Output Files

The tool generates timestamped CSV files for analysis:

### 1. Summary Report (`amstar2_summary_YYYYMMDD_HHMMSS.csv`)
- Article identifiers
- Overall confidence ratings (High/Moderate/Low/Critically low)
- Inclusion/exclusion recommendations
- Comparative results between AI judges

### 2. Detailed Evaluations
- `amstar2_anthropic_YYYYMMDD_HHMMSS.csv`: Claude evaluations
- `amstar2_openai_YYYYMMDD_HHMMSS.csv`: GPT evaluations

Each detailed file contains:
- Item-by-item AMSTAR2 scores (Yes/Partial Yes/No/N/A)
- Justifications (≤20 words per item)
- Critical weakness identification

## AMSTAR2 Implementation

The tool evaluates all 16 AMSTAR2 criteria:

### Critical Domains (7 items)
- Protocol registration before commencement
- Comprehensive literature search strategy
- List of excluded studies with justifications
- Risk of bias assessment technique
- Appropriate statistical combination methods
- Risk of bias consideration in results interpretation
- Publication bias investigation

### Non-Critical Domains (9 items)
- PICO components in research questions
- Study design selection explanation
- Duplicate study selection and data extraction
- Adequate study descriptions
- Funding sources reporting
- Risk of bias impact assessment
- Heterogeneity explanation
- Conflict of interest reporting

## Quality Control and Validation

### Inter-Rater Reliability Analysis

```r
# Example workflow for agreement analysis
library(irr)

# Load results
anthropic <- read.csv("amstar2_anthropic_YYYYMMDD_HHMMSS.csv")
openai <- read.csv("amstar2_openai_YYYYMMDD_HHMMSS.csv")

# Prepare data and calculate weighted kappa
# (Implementation depends on your specific analysis needs)
```

### Human Validation Protocol

1. **Random sampling**: Select 5-10% of evaluations for manual review
2. **Independent assessment**: Human expert evaluation using standard AMSTAR2
3. **Agreement analysis**: Calculate AI-human concordance
4. **Performance metrics**: Sensitivity, specificity, and predictive values

## Production Features

### Robust Processing
- **Checkpoint system**: Automatic recovery from interruptions
- **Error handling**: Graceful failure management with detailed logging
- **File deduplication**: Prevents unnecessary re-uploads
- **Progress tracking**: Real-time status updates

### Scalability
- **Parallel uploads**: Simultaneous API calls to both services
- **Batch processing**: Efficient handling of large document sets
- **Resource optimization**: Configurable worker limits

### Logging and Monitoring
- **Comprehensive logs**: Timestamped activity records
- **Status indicators**: Visual progress feedback
- **Error reporting**: Detailed failure diagnostics

## Methodological Considerations

### Limitations
- **AI model constraints**: Performance varies with document quality and complexity
- **Language dependency**: Optimized for English-language reviews
- **Validation required**: AI assessments should be validated against human evaluation

### Best Practices
1. **Pilot testing**: Validate on a small sample before large-scale deployment
2. **Human oversight**: Maintain expert review for critical decisions
3. **Documentation**: Record all processing parameters and model versions
4. **Reproducibility**: Use version control and detailed logs

## Troubleshooting

### Common Issues

**API Connection Errors**
```
Check internet connectivity and API key validity
Verify rate limits and usage quotas
```

**File Processing Failures**
```
Ensure PDFs are readable and not password-protected
Check file size limits (typically <20MB per file)
```

**Memory or Performance Issues**
```
Reduce parallel worker count if system resources are limited
Process files in smaller batches if necessary
```

## Development

This tool was developed using [Claude Code](https://www.anthropic.com/claude-code), Anthropic's AI-powered command line development tool, in collaboration with the research team. The final implementation, methodology, and scientific validation remain the responsibility of the authors.


## Citation

When using this tool in research publications, please cite:

```
Bressoud, N., Gay, P., Audrin, C., Lucciarini, E., & Burel, N. (2025). 
amstaR-ai: Automated systematic review quality assessment using dual AI evaluation 
(Version 1.0) [Computer software]. GitHub. 
https://github.com/bresnico/amstaR-ai
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Technical Specifications

- **R Version**: ≥4.0.0
- **Dependencies**: httr2, jsonlite, future, future.apply
- **AI Models**: Claude Sonnet 4 (Anthropic), GPT-4o-mini (OpenAI)
- **Processing**: Parallel execution with 2 workers
- **Output Format**: CSV (UTF-8 encoding)

## References

- Shea B J, Reeves B C, Wells G, Thuku M, Hamel C, Moran J et al. AMSTAR 2: a critical appraisal tool for systematic reviews that include randomised or non-randomised studies of healthcare interventions, or both BMJ 2017; 358 :j4008 doi:10.1136/bmj.j4008.
- [Anthropic Claude API Documentation](https://docs.anthropic.com/)
- [OpenAI API Documentation](https://platform.openai.com/docs/)

---

*Developed to enhance the efficiency and reproducibility of systematic review quality assessment in academic research.*
# Code Review Guidelines

**CRITICAL**: Only flag actual problems. Do not comment on code that follows these rules or suggest improvements to working configurations.

## 🚨 HIGH RISK - Security & Breaking Changes

### Terraform
- **IAM Policies**: Overly permissive policies, wildcard actions/resources, missing conditions
- **Resource Exposure**: Public access without justification, missing encryption
- **Breaking Changes**: Resource renames, destructive modifications, incompatible version updates
- **Hardcoded Secrets**: API keys, passwords, tokens in code
- **Providers (Declaration)**: Missing or incorrect `required_providers` block (wrong source or absent)
- **Providers (Versions)**: Missing/overly loose version constraints for providers
- **Core Version**: Missing or incompatible `required_version` in `terraform` block

### YAML
- **Parse Errors**: Indentation that will cause YAML parsing failures
- **Security Issues**: Exposed secrets, overly permissive permissions
- **Breaking Changes**: Modified keys that break dependent systems
- **Invalid Syntax**: Malformed YAML structure, incorrect data types

## ⚠️ MEDIUM RISK - Performance & Compliance

### Terraform
- **Resource Sizing**: Undersized/oversized instances, inefficient configurations
- **Naming Violations**: Non-snake_case variables/resources, non-hyphen-case modules
- **Missing Documentation**: Missing descriptions, incomplete README.md
- **Structure Violations**: Missing required files (terraform.tf, variables.tf, outputs.tf)
- **Code Quality**: Copy-pasted resources, missing locals for repeated values

### YAML
- **Logic Errors**: Contradictory settings, missing required keys
- **Performance Issues**: Inefficient configurations, resource limitations
- **Consistency**: Inconsistent indentation within the same logical block (only if adjacent lines show the pattern)

## ℹ️ LOW RISK - Minor Issues

### Terraform
- **Formatting**: Code not passing `terraform fmt` or `terraform validate`
- **Deprecated Syntax**: Usage of deprecated Terraform features
- **Checkov Skips**: Unjustified skip comments or removable skips
- **Module References**: Registry references instead of git URLs with commit hashes

### YAML
- **Format**: Minor formatting issues that don't affect functionality
- **Deprecated Features**: Usage of deprecated YAML features or keys

## What NOT to Flag

### General Principles
- Code that already follows the rules above
- Personal style preferences
- Valid alternative approaches
- Working configurations that meet requirements

### Terraform Specific
- Code that already follows Terraform best practices
- Different but valid resource configurations
- Alternative module structures that work

### YAML Specific
- Different but valid indentation styles
- Working configurations that function correctly
- Incomplete context issues based on assumptions about unseen parts of the file
- Cosmetic changes that don't improve functionality

## Review Behavior
- Focus on genuine issues that could cause problems
- Avoid suggesting improvements to code that works correctly
- Prioritize security and breaking change risks
- Only comment when there's a clear problem to address

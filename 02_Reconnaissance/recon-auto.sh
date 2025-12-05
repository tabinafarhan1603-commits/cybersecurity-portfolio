#!/bin/bash

# recon-auto.sh - Automated Reconnaissance Tool
# Author: Tabina
# Description: Automated subdomain enumeration and live host detection

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timestamp function
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(timestamp) - $1" | tee -a logs/progress.log
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(timestamp) - $1" | tee -a logs/progress.log
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(timestamp) - $1" | tee -a logs/progress.log
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(timestamp) - $1" | tee -a logs/progress.log
    echo -e "${RED}[ERROR]${NC} $(timestamp) - $1" >> logs/errors.log
}

# Check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_tools=()
    
    if ! command -v subfinder &> /dev/null; then
        missing_tools+=("subfinder")
    fi
    
    if ! command -v httpx &> /dev/null; then
        missing_tools+=("httpx")
    fi
    
    if ! command -v anew &> /dev/null; then
        missing_tools+=("anew")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools first"
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Validate input file
validate_input() {
    log_info "Validating input file..."
    
    if [ ! -f "input/domains.txt" ]; then
        log_error "Input file 'input/domains.txt' not found"
        exit 1
    fi
    
    if [ ! -s "input/domains.txt" ]; then
        log_error "Input file 'input/domains.txt' is empty"
        exit 1
    fi
    
    local domain_count=$(wc -l < input/domains.txt | tr -d ' ')
    log_success "Input file validated with $domain_count domains"
}

# Clean previous output files
cleanup() {
    log_info "Cleaning up previous output files..."
    
    > output/all-subdomains.txt
    > output/live.txt
    > logs/progress.log
    > logs/errors.log
    
    log_success "Cleanup completed"
}

# Main recon function
main_recon() {
    log_info "Starting reconnaissance process..."
    
    local total_domains=0
    local total_subdomains=0
    local live_hosts=0
    
    # Read domains from input file
    while IFS= read -r domain; do
        # Skip empty lines
        [[ -z "$domain" ]] && continue
        
        total_domains=$((total_domains + 1))
        log_info "Processing domain: $domain"
        
        # Subdomain enumeration with subfinder
        log_info "Running subfinder for $domain"
        if subfinder -d "$domain" -silent 2>> logs/errors.log | anew output/all-subdomains.txt >> logs/progress.log 2>> logs/errors.log; then
            local new_subs=$(subfinder -d "$domain" -silent | anew output/all-subdomains.txt | wc -l)
            log_success "Found $new_subs new subdomains for $domain"
        else
            log_error "Subfinder failed for $domain"
        fi
        
    done < input/domains.txt
    
    # Count total unique subdomains
    total_subdomains=$(sort output/all-subdomains.txt | uniq | wc -l)
    log_success "Total unique subdomains found: $total_subdomains"
    
    # Find live hosts with httpx
    log_info "Checking for live hosts..."
    if [ -s "output/all-subdomains.txt" ]; then
        if httpx -l output/all-subdomains.txt -silent -status-code -title 2>> logs/errors.log | tee output/live-temp.txt >> logs/progress.log; then
            # Format output
            while IFS= read -r line; do
                if [[ ! -z "$line" ]]; then
                    echo "$line" >> output/live.txt
                    live_hosts=$((live_hosts + 1))
                fi
            done < output/live-temp.txt
            
            rm -f output/live-temp.txt
            log_success "Found $live_hosts live hosts"
        else
            log_error "HTTPX failed to check live hosts"
        fi
    else
        log_warning "No subdomains found to check"
    fi
    
    # Final summary
    log_success "=== RECONNAISSANCE COMPLETED ==="
    log_success "Total Domains Processed: $total_domains"
    log_success "Total Unique Subdomains: $total_subdomains"
    log_success "Total Live Hosts: $live_hosts"
    log_success "Results saved in: output/live.txt"
    log_success "Logs saved in: logs/progress.log"
}

# Main execution
main() {
    echo "=========================================="
    echo "    RECON AUTOMATION TOOL"
    echo "    Started at: $(timestamp)"
    echo "=========================================="
    
    # Check dependencies
    check_dependencies
    
    # Validate input
    validate_input
    
    # Cleanup previous runs
    cleanup
    
    # Run main reconnaissance
    main_recon
    
    echo "=========================================="
    echo "    RECON AUTOMATION COMPLETED"
    echo "    Finished at: $(timestamp)"
    echo "=========================================="
}

# Run main function and handle errors
main "$@"

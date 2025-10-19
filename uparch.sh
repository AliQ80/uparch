#!/bin/bash

# uparch - Interactive Arch Linux System Update Script
# Uses gum for interactive elements and styling

set -euo pipefail

# Color definitions for gum style
HEADER_COLOR="#FF79C6"
SUCCESS_COLOR="#50FA7B"
ERROR_COLOR="#FF5555"
INFO_COLOR="#8BE9FD"
WARNING_COLOR="#FFB86C"

# Track completion status
declare -A STEP_STATUS
STEPS=("timeshift" "paru" "flatpak" "npm")

# Auto-confirm mode (skip individual step confirmations)
AUTO_CONFIRM=false

# Function to display styled headers (for main header)
header() {
	gum style \
		--foreground "$HEADER_COLOR" \
		--border-foreground "$HEADER_COLOR" \
		--border rounded \
		--padding "1 2" \
		--margin "1 2" \
		"$1"
}

# Function to display step headers (rounded border)
step_header() {
	gum style \
		--foreground "$HEADER_COLOR" \
		--border-foreground "$HEADER_COLOR" \
		--border rounded \
		--padding "1 2" \
		--margin "1 2" \
		"$1"
}

# Function to display success messages
success() {
	gum style \
		--foreground "$SUCCESS_COLOR" \
		--bold \
		"✅ $1"
}

# Function to display error messages
error() {
	gum style \
		--foreground "$ERROR_COLOR" \
		--bold \
		"❌ $1"
}

# Function to display info messages
info() {
	gum style \
		--foreground "$INFO_COLOR" \
		"ℹ️  $1"
}

# Function to display warning messages
warning() {
	gum style \
		--foreground "$WARNING_COLOR" \
		"⚠️  $1"
}

# Function to handle errors and ask if user wants to continue
handle_error() {
	local step=$1
	local message=$2

	error "$message"
	STEP_STATUS[$step]="failed"

	echo ""
	if gum confirm "Do you want to continue with the remaining steps?"; then
		return 0
	else
		echo ""
		warning "Update process aborted by user 🛑"
		show_summary
		exit 1
	fi
}

# Function to show final summary
show_summary() {
	echo ""
	header "📊 Update Summary"
	echo ""

	for step in "${STEPS[@]}"; do
		if [[ "${STEP_STATUS[$step]}" == "success" ]]; then
			success "$(echo $step | tr '[:lower:]' '[:upper:]'): Completed successfully"
		elif [[ "${STEP_STATUS[$step]}" == "failed" ]]; then
			error "$(echo $step | tr '[:lower:]' '[:upper:]'): Failed"
		elif [[ "${STEP_STATUS[$step]}" == "skipped" ]]; then
			warning "$(echo $step | tr '[:lower:]' '[:upper:]'): Skipped"
		fi
	done

	echo ""
}

# Check for required dependencies
check_dependencies() {
	local missing_deps=()

	for dep in gum timeshift paru flatpak npm; do
		if ! command -v "$dep" &>/dev/null; then
			missing_deps+=("$dep")
		fi
	done

	if [[ ${#missing_deps[@]} -gt 0 ]]; then
		error "Missing required dependencies: ${missing_deps[*]}"
		echo ""
		info "Please install missing dependencies before running this script."
		exit 1
	fi
}

# Step 1: Create Timeshift Snapshot
create_timeshift_snapshot() {
	step_header "📸 Step 1: Timeshift Snapshot"
	echo ""

	info "Creating a system snapshot before updating..."
	echo ""

	# Prompt for snapshot comment
	local comment
	comment=$(gum input \
		--placeholder "Enter a description for this snapshot (e.g., 'Before system update - $(date +%Y-%m-%d)')" \
		--width 80 \
		--prompt "Snapshot description: ")

	# Use default comment if user didn't provide one
	if [[ -z "$comment" ]]; then
		comment="System update - $(date '+%Y-%m-%d %H:%M')"
	fi

	echo ""
	info "Creating snapshot with comment: $comment"
	echo ""

	# Create snapshot (requires sudo)
	if gum spin --spinner dot --title "Creating Timeshift snapshot..." -- \
		sudo timeshift --create --comments "$comment" --scripted; then
		echo ""
		success "Timeshift snapshot created successfully 📦"
		STEP_STATUS[timeshift]="success"
		return 0
	else
		handle_error "timeshift" "Failed to create Timeshift snapshot"
		return 1
	fi
}

# Step 2: Update system with paru
update_with_paru() {
	step_header "📦 Step 2: System Update (Paru)"
	echo ""

	if [[ "$AUTO_CONFIRM" == false ]]; then
		if ! gum confirm "Proceed with system update using paru?"; then
			warning "System update skipped by user 🙅"
			STEP_STATUS[paru]="skipped"
			return 0
		fi
	fi

	echo ""
	info "Updating system packages..."
	echo ""

	# Run paru (interactive, so we don't use gum spin)
	if paru -Syu; then
		echo ""
		success "System update completed successfully 🎯"
		STEP_STATUS[paru]="success"
		return 0
	else
		echo ""
		handle_error "paru" "System update failed"
		return 1
	fi
}

# Step 3: Update Flatpak packages
update_flatpak() {
	step_header "📱 Step 3: Flatpak Update"
	echo ""

	if [[ "$AUTO_CONFIRM" == false ]]; then
		if ! gum confirm "Proceed with Flatpak updates?"; then
			warning "Flatpak update skipped by user 🙅"
			STEP_STATUS[flatpak]="skipped"
			return 0
		fi
	fi

	echo ""
	info "Updating Flatpak packages..."
	echo ""

	# Check if any flatpaks are installed
	if ! flatpak list &>/dev/null || [[ $(flatpak list | wc -l) -eq 0 ]]; then
		warning "No Flatpak packages installed. Skipping... 🚫"
		STEP_STATUS[flatpak]="skipped"
		return 0
	fi

	# Update flatpak packages
	if flatpak update -y; then
		echo ""
		success "Flatpak packages updated successfully 📲"
		STEP_STATUS[flatpak]="success"
		return 0
	else
		echo ""
		handle_error "flatpak" "Flatpak update failed"
		return 1
	fi
}

# Step 4: Update NPM global packages
update_npm_global() {
	step_header "🌐 Step 4: NPM Global Packages Update"
	echo ""

	if [[ "$AUTO_CONFIRM" == false ]]; then
		if ! gum confirm "Proceed with NPM global package updates?"; then
			warning "NPM update skipped by user 🙅"
			STEP_STATUS[npm]="skipped"
			return 0
		fi
	fi

	echo ""
	info "Updating NPM global packages..."
	echo ""

	# Check if any global packages are installed
	local global_packages
	global_packages=$(npm list -g --depth=0 2>/dev/null || true)

	if [[ -z "$global_packages" ]] || [[ $(echo "$global_packages" | wc -l) -le 1 ]]; then
		warning "No global NPM packages installed. Skipping... 🚫"
		STEP_STATUS[npm]="skipped"
		return 0
	fi

	# Update global packages
	if gum spin --spinner dot --title "Updating NPM global packages..." -- \
		npm update -g; then
		echo ""
		success "NPM global packages updated successfully 📦"
		STEP_STATUS[npm]="success"
		return 0
	else
		echo ""
		handle_error "npm" "NPM global package update failed"
		return 1
	fi
}

# Main execution
main() {
	clear

	header "🚀 Arch Linux System Update (uparch)"
	echo ""

	# Check dependencies first
	info "Checking dependencies..."
	check_dependencies
	success "All dependencies found ✨"
	echo ""

	# Ask if user wants to run all updates without individual confirmations
	if gum confirm "Do you want to run all updates automatically without asking for confirmation at each step?"; then
		AUTO_CONFIRM=true
		success "Auto-confirm mode enabled - all steps will run automatically 🚀"
		echo ""
	else
		info "You will be asked to confirm each step individually 🔍"
		echo ""
	fi

	# Initialize step status
	for step in "${STEPS[@]}"; do
		STEP_STATUS[$step]="pending"
	done

	# Execute update steps
	create_timeshift_snapshot
	echo ""

	update_with_paru
	echo ""

	update_flatpak
	echo ""

	update_npm_global
	echo ""

	# Show final summary
	show_summary

	gum style \
		--foreground "$SUCCESS_COLOR" \
		--border-foreground "$SUCCESS_COLOR" \
		--border rounded \
		--padding "1 2" \
		--margin "1 0" \
		"System update process completed! 🎉"
}

# Run main function
main

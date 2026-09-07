# -----------------------------------------------------
# MAIN ZSH ENTRYPOINT
# -----------------------------------------------------

# Load Modular ZSH Configs
for file in ~/.config/zshrc/*; do
    source "$file"
done
alias awake='~/.config/matrix/scripts/caffeine.sh toggle'

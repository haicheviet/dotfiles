# Edit and rerun
function edit_and_run() {
	BUFFER="fc"
	zle accept-line
}
zle -N edit_and_run
bindkey "^b" edit_and_run

# Enter
function enter_line() {
	zle accept-line
}
zle -N enter_line
bindkey "^o" enter_line

# Sudo
function add_sudo() {
	BUFFER="sudo "$BUFFER
	zle end-of-line
}
zle -N add_sudo
bindkey "^s" add_sudo

# Home - Navigates to the current root workspace
function git_root() {
	BUFFER="cd $(git rev-parse --show-toplevel || echo ".")"
	zle accept-line
}
zle -N git_root
bindkey "^h" git_root


# whois a domain or a URL
function whois() {
	local domain=$(echo "$1" | awk -F/ '{print $3}') # get domain from URL
	if [ -z $domain ] ; then
		domain=$1
	fi
	echo "Getting whois record for: $domain …"

	# avoid recursion
					# this is the best whois server
													# strip extra fluff
	/usr/bin/whois -h whois.internic.net $domain | sed '/NOTICE:/q'
}

# Create a new directory and enter it
function md() {
	mkdir -p "$@" && cd "$@"
}

# Copy w/ progress
cp_p () {
  rsync -WavP --human-readable --progress $1 $2
}

# preview csv files. source: http://stackoverflow.com/questions/1875305/command-line-csv-viewer
function csvpreview(){
      sed 's/,,/, ,/g;s/,,/, ,/g' "$@" | column -s, -t | less -#2 -N -S
}
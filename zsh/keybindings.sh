# Create a new directory and enter it
function md() {
	mkdir -p "$@" && cd "$@"
}

# Copy w/ progress
cp_p () {
  rsync -WavP --human-readable --progress $1 $2
}

# Preview csv files. source: http://stackoverflow.com/questions/1875305/command-line-csv-viewer
function csvpreview(){
      sed 's/,,/, ,/g;s/,,/, ,/g' "$@" | column -s, -t | less -#2 -N -S
}

# Extract archives - use: extract <file>
function extract() {
	if [ -f "$1" ] ; then
		local filename=$(basename "$1")
		local foldername="${filename%%.*}"
		local fullpath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' "$1"`
		local didfolderexist=false
		if [ -d "$foldername" ]; then
			didfolderexist=true
			read -p "$foldername already exists, do you want to overwrite it? (y/n) " -n 1
			echo
			if [[ $REPLY =~ ^[Nn]$ ]]; then
				return
			fi
		fi
		mkdir -p "$foldername" && cd "$foldername"
		case $1 in
			*.tar.bz2) tar xjf "$fullpath" ;;
			*.tar.gz) tar xzf "$fullpath" ;;
			*.tar.xz) tar Jxvf "$fullpath" ;;
			*.tar.Z) tar xzf "$fullpath" ;;
			*.tar) tar xf "$fullpath" ;;
			*.taz) tar xzf "$fullpath" ;;
			*.tb2) tar xjf "$fullpath" ;;
			*.tbz) tar xjf "$fullpath" ;;
			*.tbz2) tar xjf "$fullpath" ;;
			*.tgz) tar xzf "$fullpath" ;;
			*.txz) tar Jxvf "$fullpath" ;;
			*.zip) unzip "$fullpath" ;;
			*) echo "'$1' cannot be extracted via extract()" && cd .. && ! $didfolderexist && rm -r "$foldername" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

function gcm() {
    # Check if GROQ_API_KEY is set
    if [ -z "$GROQ_API_KEY" ]; then
        echo "Error: GROQ_API_KEY is not set. Please set it before running this command."
        return 1
    fi

    staged_changes=$(git diff --cached | jq -Rsa '.')
    if [ -z "$staged_changes" ]; then
        echo "No staged changes found. Please stage your changes before generating a commit message."
        return 1
    fi

    # Function to generate commit message
    generate_commit_message() {
    staged_changes=$(git diff --cached | jq -Rsa '.')
    response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
     -H "Authorization: Bearer $GROQ_API_KEY" \
     -H "Content-Type: application/json" \
        -d "$(jq -n --arg changes "$staged_changes" '{
            model: "gemma2-9b-it",
            messages: [
                {role: "system", content: "You are a helpful assistant. You will only generate one-line commit message, nothing more."},
                {role: "user", content: "Below is a diff of all staged changes, coming from the command:```\n\($changes)\n```\nPlease generate a concise, one-line commit message for these changes."}
            ]
        }')")
    commit_message=$(echo "$response" | jq -r '.choices[0].message.content' | sed 's/"//g' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    echo "$commit_message"
    }

    # Function to read user input compatibly with both Bash and Zsh
    read_input() {
        if [ -n "$ZSH_VERSION" ]; then
            echo -n "$1"
            read -r REPLY
        else
            read -p "$1" -r REPLY
        fi
    }

    # Main script
    echo "Generating..."
    commit_message=$(generate_commit_message)

    while true; do
        echo -e "\nProposed commit message:"
        echo "$commit_message"

        read_input "Do you want to (a)ccept, (e)dit, (r)egenerate, or (c)ancel? "
        choice=$REPLY

        case "$choice" in
            a|A )
                if git commit -m "$commit_message"; then
                    echo "Changes committed successfully!"
                else
                    echo "Commit failed. Please check your changes and try again."
                    return 1
                fi
                if git push; then
                    echo "Pushed changes successfully!"
                    return 0
                else
                    echo "Push failed. Please check your changes and try again."
                    return 1
                fi
                ;;
            e|E )
                read_input "Enter your commit message: "
                commit_message=$REPLY
                if [ -n "$commit_message" ] && git commit -m "$commit_message"; then
                    echo "Changes committed successfully with your message!"
                else
                    echo "Commit failed. Please check your message and try again."
                    return 1
                fi
                if git push; then
                    echo "Pushed changes successfully!"
                    return 0
                else
                    echo "Push failed. Please check your changes and try again."
                    return 1
                fi
                ;;
            r|R )
                echo "Regenerating commit message..."
                commit_message=$(generate_commit_message)
                ;;
            c|C )
                echo "Commit cancelled."
                return 1
                ;;
            * )
                echo "Invalid choice. Please try again."
                ;;
        esac
    done
}
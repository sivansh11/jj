#!/bin/bash

# Script to compress all .gif files using ffmpeg with aggressive settings
# and replace the original files

for gif_file in *.gif; do
    if [ -f "$gif_file" ]; then
        echo "Processing: $gif_file"
        
        # Create temporary file
        temp_file="${gif_file%.gif}_temp.gif"
        
        # Try multiple compression methods
        echo "Attempting aggressive compression..."
        
        # Method 1: Reduce colors and frame rate
        ffmpeg -i "$gif_file" -vf "fps=8,scale=iw:ih:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:reserve_transparent=0[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" -f gif "$temp_file" -y
        
        # Check if conversion was successful
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            # Get original and new file sizes
            original_size=$(stat -c%s "$gif_file")
            new_size=$(stat -c%s "$temp_file")
            
            echo "Original size: $original_size bytes"
            echo "Compressed size: $new_size bytes"
            
            if [ $new_size -lt $original_size ]; then
                reduction=$(( (original_size - new_size) * 100 / original_size ))
                echo "Reduction: $reduction%"
                
                # Replace original with compressed version
                mv "$temp_file" "$gif_file"
                echo "Successfully compressed: $gif_file"
            else
                echo "No compression achieved, trying even more aggressive settings..."
                rm "$temp_file"
                
                # Method 2: Even more aggressive - reduce to 64 colors and lower fps
                ffmpeg -i "$gif_file" -vf "fps=5,scale=iw:ih:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=64:reserve_transparent=0[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" -f gif "$temp_file" -y
                
                if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
                    new_size=$(stat -c%s "$temp_file")
                    echo "Second attempt - Compressed size: $new_size bytes"
                    
                    if [ $new_size -lt $original_size ]; then
                        reduction=$(( (original_size - new_size) * 100 / original_size ))
                        echo "Reduction: $reduction%"
                        mv "$temp_file" "$gif_file"
                        echo "Successfully compressed: $gif_file"
                    else
                        echo "Still no compression, keeping original"
                        rm "$temp_file"
                    fi
                fi
            fi
            echo "---"
        else
            echo "Error: Failed to process $gif_file"
            [ -f "$temp_file" ] && rm "$temp_file"
        fi
    fi
done

echo "All .gif files processed!"

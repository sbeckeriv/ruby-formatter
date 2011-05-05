#!/usr/bin/env ruby
# 
# == Synopsis
#
# Simple Ruby Formatter
#
# Created by: Stephen Becker IV
# Contributions: Andrew Nutter-Upham  
# Contact: sbeckeriv@gmail.com
# SVN: http://svn.stephenbeckeriv.com/code/ruby_formatter/
# 
# Its been done before RadRails did,
# http://vim.sourceforge.net/tips/tip.php?tip_id=1368 that guy did it, but I did
# not look for a ruby formatter untill i was done.
# 
# It is called simple formatting because it is. I have the concept of 3 differnt
# indent actions In, Out and Both. I have mixed the concept of indenting and
# outdenting. Out means you have added white space and in means you remove a layer
# of white space.
# 
# Basic logic
# 	Decrease current depth if
# 			((the it is not a one line if unless statment
# 			(need to lookfor more oneline blocks) and it ends with end
# 			or if the } count is larger then {)
# 		or
# 			the first word is in the both list)
# 			
# 		and
# 			depth is larger then zero
# 			
# 	Increase current depth if
# 			It is not a one liner
# 		and
# 			(the word is in the out list
# 		or
# 			the word is in the both list
# 		or
# 			it looks like a start block)
# 		and
# 			temp_depth is nil (used for = comment blocks)
# 
# 
# Sure there are some regx's and a crap load of gsubs, but it still simple. Its
# not like its a pychecker (http://www.metaslash.com/brochure/ipc10.html)
# 
# == Usage
# 
# ruby [options] filelist
#
# options:
#   -s # will change the indent to a space count of # per level
#        by default we space with 1 tab per level
#   -b # create a backup file
# 
# examples:
# ruby simple_formatter.rb -s 3 -b /moo/cluck/cow.rb
# runs with the indent of 3 spaces,creates a backup file, and formats moo/cluck/cow.rb
# 
# 
# Tested with random files off of koders.com
# 
#

require 'getoptlong'
require 'rdoc/usage'

opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--spaces', '-s', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--backup', '-b', GetoptLong::OPTIONAL_ARGUMENT ]
  )

space_count = 2
backup = false

opts.each do |opt, arg|
  case opt
    when '--help'
      RDoc::usage
    when '--spaces'
      space_count = arg.to_i
    when '--backup'
      backup = true
  end
end

if ARGV.length < 1
  puts "Missing filelist argument (try --help)"
  exit 0
end

array_loc = ARGV

array_loc.each{|file_loc|
	f=File.open(file_loc,"r")
	text=f.read
	f.close
	new_text=""
	current_depth=0
  spaces =  " "*space_count
	
	indenter=  spaces || "\t"
	
	
	require "fileutils"
	require "pp"
	#find if the string is a start block
	#return true if it is
	#rules
	# does not include end at the end
	# and ( { out number the } or it includes do 
	def start_block?(string)
		#if it has do and ends with end its a single line block
		# if we have more { then }  its the start of a block should raise if } is greater?
		#the crazy gsubs remove "{}" '{}' and /{}/  so string or regx wont be counted for blocks
		return true if  (!string.rstrip.slice(/ end$/) && (string.gsub(/".*"/,"").gsub(/'.*'/,"").gsub(/\/.*\//,"").scan("{").size>string.gsub(/".*"/,"").gsub(/'.*'/,"").gsub(/\/.*\//,"").scan("}").size) || string.include?(" do "))
		false
	end
	#is this an end block?
	#rules
	#its not a one liner
	#and it ends with end
	#or } out number {
	def check_ends?(string)
		#check for one liners end and }
		return true if  (!(string.match(/(unless|if).*(then).*end/)) && string.rstrip.slice(/end$/))|| (string.gsub(/".*"/,"").gsub(/'.*'/,"").gsub(/\/.*\//,"").scan("{").size<string.gsub(/".*"/,"").gsub(/'.*'/,"").gsub(/\/.*\//,"").scan("}").size) 
		false
	end
	
	#look at first work does it start with one of the out works
	def in_outs?(string)
		["def","class","module","begin","case","if","unless","loop","while","until","for"].each{|x|
			if string.lstrip.slice(/^#{x}/)
					return true
			end
			
		}
		false
	end
	#look at first work does it start with one of the both words?
	def in_both?(string)
		["elsif","else","when","rescue","ensure"].each{|x|
		return true if string.lstrip.slice(/^#{x}/)
		}
		false
	end
	#extra formatting for the line
	#we wrap = with spaces
	def line_clean_up(x)
		x=x.lstrip
		x=x.gsub(/[a-zA-Z\]\'\"{\d]+=[a-zA-Z\[\'\"{\d]+/){|x| x.split("=").join(" = ")}
		#or equal is failing to work in the same way
		#x=x.gsub(/[a-zA-Z\]\'\"{\d]+=[a-zA-Z\[\'\"{\d]+/){|x| x.split("||=").join(" ||= ")}
		return x
	end
	
	
	#left over notes
	#these are how we change the depth 
	#outs=["def","class","module","begin","case","if","unless","loop","while","until","for"]
	#both=["elsif","else","when","rescue","ensure"]
	#ins=["end","}"]
	#reset_depth=["=begin","=end"]
	
	temp_depth=nil
	
	
	text.split("\n").each{ |x|
		#comments
		#The first idea was to leave them alone.
		#after running a few test i did not like the way it looked
		if temp_depth	
			new_text<<x<<"\n"
			#block comments, its going to get ugly
			unless x.lstrip.scan(/^\=end/).empty?
				#swap and set
				current_depth=temp_depth
				temp_depth=nil
			end
			next
		end
		
		#block will always be 0 depth
		#block comments, its going to get ugly
		unless x.lstrip.scan(/^\=begin/).empty?
			#swap and set
			temp_depth=current_depth
			current_depth=0
		end
		#whats the first word?
		text_node = x.split.first || ""
		
		#check if its in end or both and that the current_depth is >0
		#maybe i should raise if it goes negative ?
		current_depth -= 1 if (check_ends?(x)||in_both?(text_node)) && current_depth>0
		
		new_text<<indenter*current_depth<<line_clean_up(x)<<"\n"
		
		
		#we want to kick the indent out one
		#  x.match(/(unless|if).*(then).*end/): we use this match one liners for if statements not one-line blocks
		# in_outs? returns true if the first work is in the out array
		# in_both? does the same for the both array
		# start_block looks for to not have an end at the end and {.count > }.count and if the word do is in there
		# temp_depth is used when we hit the = comments should be nil unless you are in a comment
		current_depth+=1 if !(x.match(/(unless|if).*(then).*end/)) && ((in_outs?(text_node) || in_both?(text_node) || start_block?(x)) && !temp_depth)
	}
	FileUtils.cp("#{file_loc}","#{file_loc}.bk.#{Time.now}") if backup
	f=File.open("#{file_loc}","w+")
	f.puts new_text
	f.close
	puts "Done!"
}

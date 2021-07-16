#used to extract graphics from the rom file as .bin

FileToOpen = "Mario Bros. (U) [!].nes"
FileToGen = "MarioBrosGFX.bin"

CodeKBs = 16 #how many KBs of code to skip to get to the GFX (vanilla unmodified rom is 24KBs in total, with 16 being for code and 8 for GFX)

#solution from stackoverflow.com, thanks to Jeremy for the code.
in_file = open(FileToOpen, "rb") # opening for [r]eading as [b]inary

#there's probably a more elegant way of doing this, but idk. first read skips code bytes, after which it copies graphics
in_file.read(CodeKBs*1024+16) # skip 16KB (and the first 16 bytes of iNES header)

data = in_file.read(8192) #copy GFX
in_file.close()

out_file = open(FileToGen, "wb") # open for [w]riting as [b]inary
out_file.write(data)
out_file.close()

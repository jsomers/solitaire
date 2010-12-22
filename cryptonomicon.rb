# A Ruby implementation of Schneier's Solitaire encryption algorithm from Neal
# Stephenson's novel, Cryptonomicon. See http://www.schneier.com/solitaire.html.

require 'rubygems'
require 'highline/import'

class Array
  def shuffle
    return sort_by { rand }
  end
  
  def move_joker(ab)
    old = self.index(ab)
    self.delete(ab)
    nw = old + ab.length
    return self.insert(nw > 53 ? nw - 53 : nw, ab)
  end

  def move_jokers
    dck = self.move_joker("!")
    return dck.move_joker("!!")
  end
  
  def triple_cut
    cts = [self.index("!"), self.index("!!")].sort
    frst = self.slice(0, cts.first)
    mid = self.slice(cts.first, cts.last - cts.first + 1)
    lst = self.slice(cts.last + 1, 53 - cts.last)
    return lst + mid + frst
  end

  def count_cut(v=nil)
    ct = (v || val(self.last))
    if ct == 53
      return self
    else
      top = self.slice(0, ct)
      bot = self.slice(ct, 53 - ct)
      return bot + top + [self.last]
    end
  end
  
  def solitaire
    dck = self.move_jokers
    dck = dck.triple_cut
    return dck.count_cut
  end

  def stream(n)
    i, dck = -1, self
    while (i += 1) < n
      dck = dck.solitaire
      x = val( dck[val(dck.first)] )
      if x == 53
        i -= 1
      else
        yield x
      end
    end
  end
  
  def key(keystring)
    dck = self
    keystring.split("").each do |letter|
      dck = dck.solitaire
      dck = dck.count_cut( ("A".."Z").to_a.index(letter) + 1 )
    end
    return dck
  end
end

class String
  def xor(v)
    letters = ("A".."Z").to_a
    return letters[ (letters.index(self) + v) % 26 ]
  end
  
  def pad
    if self.length % 5 != 0
      return self + "X" * (5 - self.length % 5)
    else
      return self
    end
  end
  
  def blocks
    x = []
    (0..self.length / 5).each do |i|
      x << self.slice(i * 5, 5)
    end
    return x.reject {|b| b.empty?}.join(" ")
  end
  
  def encrypt(dck)
    s, letters = "", self.pad.split("").select {|a| a.match(/[a-zA-Z]/)}
    dck.stream(letters.length) {|l| s += letters.shift.xor(l)}
    return s.blocks
  end

end

def deck
  suits = ["c", "d", "h", "s"]
  ranks = ["A"] + (2..10).to_a + ["J", "Q", "K"]
  return suits.collect {|s| ranks.collect {|r| "#{r}#{s}"}}.flatten + ["!", "!!"]
end

def val(card)
  if card.include? "!"
    return 53
  else
    spcl = {"A" => 1, "J" => 11, "Q" => 12, "K" => 13}
    add = {"c" => 0, "d" => 13, "h" => 26, "s" => 39}
    rank, suit = card.split("")[0..-2].join(""), card.split("").last
    return (rank.to_i.zero? ? spcl[rank] : rank.to_i) + add[suit]
  end
end

# Verify that Scheiner's examples work:
#puts "Sample 1:"
#outs = []
#deck.stream(10) {|x| outs << x}
#p outs # raw numerical output
#
#p ("A" * 10).encrypt(deck) # ciphered
#
#puts "\nSample 2:"
#outs = []
#deck.key("FOO").stream(15) {|x| outs << x}
#p outs
#
#p ("A" * 15).encrypt( deck.key("FOO") )
#
#puts "\nSample 3:"
#p "SOLITAIRE".encrypt( deck.key("CRYPTONOMICON") )


# Encrypt text as you type

class HighLine
	public :get_character
end

input = HighLine.new

key = input.ask("Encryption key: ") {|q| q.echo = "*"}
i = -1

cpher = ""
dck = deck.key(key.upcase)
print "Message: "
while (c = input.get_character) != "\e" do
  begin
    i += 1
    if i % 5 == 0 and i > 0 then print " " end
    dck = dck.solitaire
    x = val( dck[val(dck.first)] )
    cph = c.chr.upcase.xor(x)
    cpher += cph
	  print cph
	  
  rescue
    break
  end
end

# Send an e-mail
from = input.ask("\nFrom: ")
password = input.ask("Password: ") {|q| q.echo = "*"}
recipient = input.ask("To: ")

require 'tlsmail'  
require 'time'  
  
content = <<EOF  
From: #{from}
To: #{recipient}
Subject: [encrypted message]
Date: #{Time.now.rfc2822} 
  
#{cpher.blocks}
EOF

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, password, :login) do |smtp|  
  smtp.send_message(content, from, recipient)  
end
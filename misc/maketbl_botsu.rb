pattern = /([0-9A-F]{2})([0-9A-F]{2}) ([0-9A-F]{4})/i

unicode_index = Array.new(0x100) { [] }
sjis_table = Array.new(0x100) { [] }

total_bytes = 0

file = File.open('u2stbl.txt')
file.each_line do |line|
  if pattern =~ line
    unicode_hi = $1
    unicode_lo = $2
    sjis = $3

    n = unicode_hi.to_i(16)

    unicode_index[n].push "$#{unicode_lo}"
    sjis_table[n].push "$#{sjis}"
  end
end

puts ".data"
puts ".quad"
puts ""

puts "U2STableIndex::"
puts "_:"
unicode_index.each_with_index do |elem, i|
  puts ".dc U_#{sprintf('%02X',i)}xx-_"
  total_bytes += 2
end
puts ".dc U_100xx-_"
total_bytes += 2
puts ""

puts "U2STableMap::"
unicode_index.each_with_index do |elem, i|
  dc = elem.count > 0 ? " .dc.b #{elem.join(",")}" : ""
  puts "U_#{sprintf('%02X',i)}xx:#{dc}"
  total_bytes += elem.count
end
puts "U_100xx:"
puts ""

puts ".even"
puts "U2STableSjis::"
sjis_table.each_with_index do |elem, i|
  dc = elem.count > 0 ? " .dc #{elem.join(",")}" : ""
  puts "S_#{sprintf('%02X',i)}xx:#{dc}"
  total_bytes += elem.count * 2
end

puts ""
puts ";size=#{total_bytes}"
puts ".end"

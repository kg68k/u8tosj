pattern = /([0-9A-F]{2})([0-9A-F]{2}) ([0-9A-F]{4})/i

STDOUT.binmode

u2s_table = Array.new(0x100) { Array.new(0x100) }
num_table = Array.new(0x100, 0)

total_bytes = 0

file = File.open('u2stbl.txt')
file.each_line do |line|
  if pattern =~ line
    unicode_hi = $1
    unicode_lo = $2
    sjis = $3

    hi = unicode_hi.to_i(16)
    u2s_table[hi][unicode_lo.to_i(16)] = "$#{sjis}"
    num_table[hi] += 1
  end
end

puts ".data"
puts ".quad"
puts ""

puts "U2STableBufferSize::"
# 各Shift_JIS文字配列へのポインタ配列×サイズ
pointer_buf_size = 256 * 4
# 必要なShift_JIS文字配列の数(有効なコードポイントが皆無のブロック用に+1)×サイズ
sj_table_size = (256 - num_table.count(0) + 1) * 256 * 2
puts ".dc.l #{pointer_buf_size+sj_table_size}"
total_bytes += 4
puts ""

puts "U2STableBitmap::"
u2s_table.each_slice(32) do |longword|
  bin = longword.each_slice(8).map {|byte| byte.map {|a| a.any? ? '1' : '0'}.join ''}
  puts ".dc.l %#{bin.join '_'}"
  total_bytes += 4
end
puts ""


puts "U2STableOffset::"
u2s_table.each_with_index do |array, high|
  next if num_table[high] == 0

  puts ".dc U_#{sprintf('%02X',high)}xx-$"
  total_bytes += 2
end
puts ""

u2s_table.each_with_index do |array, high|
  next if num_table[high] == 0

  puts "U_#{sprintf('%02X',high)}xx:"

  flag = array.map {|sjis| sjis ? '1' : '0'}.each_slice(16).map {|bits| sprintf('$%04x',bits.join('').to_i(2))}
  puts ".dc #{flag.join(',')}"
  total_bytes += 256/8

  sj = array.select {|sjis| sjis}

  # HASは1行1022バイトまでしか読み込めないので、長くなりすぎないよう分割して出力する
  sj.each_slice(128) do |s|
    puts ".dc #{s.join(',').downcase}"
  end
  total_bytes += sj.count * 2
end
puts ""

puts ";size=#{total_bytes}"
puts ".end"

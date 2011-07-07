require 'matrix'
require 'set'

$stdin = File.open(File.dirname(__FILE__) + '/source.txt')
$output = File.open(File.dirname(__FILE__) + '/results.txt', 'a')
$any_percent = 0.01
$range = 5
$/ = "\n\n"

def row_str(row)
  result = ''
  row.each do |x|
    x = x.to_i if x == x.to_i
    result << x.to_s.rjust($range)
  end
  result
end

def matrix_str(a, b = nil, spr = '|')
  a = a.to_a
  b = b.to_a
  result = ''
  a.each_index do |i|
    result << row_str(a[i])
    if b
      result << spr.rjust($range)
      result << row_str(b[i]) if b[i]
    end
    result << "\n"
  end
  result
end

def source_matrix
  matrix_str = gets.chomp.split('--').map { |s| s.strip }
  b_nb = read_matrix(matrix_str[0])
  b_b = read_matrix(matrix_str[1])
  [b_nb, b_b]
end

def read_matrix(str)
  matrix = str.split("\n")
  matrix.map! do |row_str|
    row = []
    row_str.strip.split(/\s/).map do |x|
      row << x.to_f unless x == ''
    end
    row
  end

  Matrix[*matrix]
end

def bust(from, to, arr, limit)
  variants = []
  for i in (from...to)
    new_arr = arr.clone
    new_arr << i
    if limit == 0
      variants << new_arr
    else
      variants += bust(i + 1, to, new_arr, limit - 1)
    end
  end
  variants
end

def all_variants(max, n)
  bust(0, max, [], n - 1)
end

def matrix_without_columns(matrix, column_indexes)
  columns = matrix.column_vectors
#  column_indexes = [column_indexes].flatten
  column_indexes.sort! { |a, b| b <=> a }
  column_indexes.each { |i| columns.delete_at(i) }
  Matrix[*columns].t
end

def matrix_with_columns(matrix, column_indexes)
  columns = matrix.column_vectors
  column_indexes.sort!
  result = []
  column_indexes.each { |i| result << columns[i] }
  Matrix[*result].t
end

def matrix_minus(matrix)
  Matrix.build(matrix.row_size, matrix.column_size) { 0 } - matrix
end

def build_final_x(x, extra_column_indexes)
  ident = Matrix.identity(extra_column_indexes.size).to_a
  result = x.row_vectors
  extra_column_indexes.sort.each_index do |i|
    result.insert(extra_column_indexes[i], ident[i])
  end
  Matrix[*result]
end

def find_all_solutions(matrix)
  all_results = []

  z = matrix.row_size - matrix.rank
  ident = Matrix.identity(z)

  extra_columns_variants = all_variants(matrix.column_size, matrix.column_size - matrix.rank)
  inner_extra_columns_variants = all_variants(matrix.row_size, z)
  total_variants = extra_columns_variants.size * inner_extra_columns_variants.size
  step = 100.0 / total_variants

  puts "Total possible variants for replacing rows and columns: #{total_variants}"

  percent = 0
  prev_percent = 0
  extra_columns_variants.each do |extra_columns|
    bt = matrix_without_columns(matrix, extra_columns).t

    inner_extra_columns_variants.each do |inner_extra_columns|
      percent += step
      unless prev_percent == (percent / $any_percent).to_i
        puts "#{percent.round((1.0 / $any_percent).to_s.size)}%"
        prev_percent = (percent / $any_percent).to_i
      end

      bt1 = matrix_without_columns(bt, inner_extra_columns)
      next if bt1.det == 0

      bt2 = matrix_with_columns(bt, inner_extra_columns)
      a = matrix_minus(bt2) * ident
      x = bt1.inverse * a
      final_x = build_final_x(x, inner_extra_columns)

      all_results << final_x
    end
  end

  all_results
end

def consist_fractional?(matrix)
  matrix.to_a.each do |row|
    row.each do |num|
      return true unless num * 10 == (num * 10).to_i
    end
  end
  false
end

def remote_fractional(set_of_results)
  arr_of_results = set_of_results.to_a
  (arr_of_results.size - 1).downto(0) do |i|
    arr_of_results.delete_at(i) if consist_fractional?(arr_of_results[i])
  end
  arr_of_results
end

def main
  sm = source_matrix
  b_nb = sm[0]
  b_b = sm[1]
  separator = '-' * (b_nb.column_size + b_b.column_size + 1) * $range + "\n"

  src_matrix_str = "Source matrix:\n"
  src_matrix_str << separator
  src_matrix_str << matrix_str(b_nb, b_b)
  src_matrix_str << separator
  src_matrix_str << "Rank of source Bodenshtain matrix: #{b_b.rank}\n\n"

  puts src_matrix_str
  $output.write(src_matrix_str)

  result_str = ''
  if b_b.rank < b_b.column_size
    all_solutions = find_all_solutions(b_b)
    puts "Was found #{all_solutions.size} possible solutions"
    results = Set.new(all_solutions)
    puts "and only #{results.size} different solutions"
    results = remote_fractional(results)
    puts "and #{results.size} solutions without fractional"
    result_str << "Results of calculations: #{results.size}\n\n"
    results.each do |x_result|
      final_result = b_nb.t * x_result
      result_str << matrix_str(x_result, final_result, '>>')
      unless x_result == results.last
        result_str << '-' * (x_result.column_size + final_result.column_size + 1) * $range + "\n"
      end
    end
  else
    msg = "The rank of source Bodenshtain matrix equals the number of columns\n"
    result_str << msg
    puts msg
  end

  $output.write(result_str + "\n")
  puts "Finished! (="
end

main
# Код описанный ниже является сугубо кривым, в плане реализации.
# Он был написан мною, когда я плохо понимал силу Ruby.
# Но, хоть код и написан плохо, он таки решает задачу Хориути

require 'matrix'
require 'set'

# Заменяем дефолтный поток ввода на файл
$stdin = File.open(File.dirname(__FILE__) + '/source.txt')
# Заменяем дефолтный поток вывода на файл
$output = File.open(File.dirname(__FILE__) + '/results.txt', 'w')
$any_percent = 0.01
$range = 5 # Отступ
$/ = "\n\n" # Признак завершнеия ввода

# Функция вывода одной строки матрицы. Если числа в строке - целые - они округляются
def row_str(row)
  result = ''
  row.each do |x|
    x = x.to_i if x == x.to_i
    result << x.to_s.rjust($range)
  end
  result
end

# Функция вывода результирующих матриц
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

# Преобразование текста, содержащего матрицу, в матрицу
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

# Чтение исходных матриц, где символом разделителем между матрицами является "--"
def source_matrix
  matrix_str = gets.chomp.split('--').map { |s| s.strip }
  b_nb = read_matrix(matrix_str[0])
  b_b = read_matrix(matrix_str[1])
  [b_nb, b_b]
end

# Рекурсивная функция нахождения всех возможных вариантов сочетания элементов массива
# аналог библиотечной функции Array::combination, в сочетании с описанным ниже методом all_variants
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

# См. пояснение к предыдущему методу
def all_variants(max, n)
  bust(0, max, [], n - 1)
end

# Исключает из матрицы указанные столбцы, и транспонирует матрицу
def matrix_without_columns(matrix, column_indexes)
  columns = matrix.column_vectors
#  column_indexes = [column_indexes].flatten
  column_indexes.sort! { |a, b| b <=> a }
  column_indexes.each { |i| columns.delete_at(i) }
  Matrix[*columns].t
end

# Исключает из матрицы все столбцы, кроме указанных, и транспонирует матрицу
def matrix_with_columns(matrix, column_indexes)
  columns = matrix.column_vectors
  column_indexes.sort!
  result = []
  column_indexes.each { |i| result << columns[i] }
  Matrix[*result].t
end

# Возвращает матрицу, у которой каждый элемент с противоположным знаком
def matrix_minus(matrix)
  Matrix.build(matrix.row_size, matrix.column_size) { 0 } - matrix
end

# Составляет финальную матрицу, содержащую отброшенные строки, т.е. вставляет в полученную матрицу отброшенные строки
# где каждая отброшенная (и теперь вставляемая) строка является строкой единичной матрицы
def build_final_x(x, extra_column_indexes)
  ident = Matrix.identity(extra_column_indexes.size).to_a
  result = x.row_vectors
  extra_column_indexes.sort.each_index do |i|
    result.insert(extra_column_indexes[i], ident[i])
  end
  Matrix[*result]
end

# Функция нахождения всех решений
def find_all_solutions(matrix)
  all_results = []

  # определяем количество инвариантов
  z = matrix.row_size - matrix.rank
  ident = Matrix.identity(z)

  # определяем инварианты индексов столбцов и строк исходной матрицы
  extra_columns_variants = all_variants(matrix.column_size, matrix.column_size - matrix.rank)
  inner_extra_columns_variants = all_variants(matrix.row_size, z)
  total_variants = extra_columns_variants.size * inner_extra_columns_variants.size # количество инвариантов
  step = 100.0 / total_variants # для вывода завершённости расчёта (в процентах)

  puts "Total possible variants for replacing rows and columns: #{total_variants}"

  percent = 0
  prev_percent = 0
  # по каждому инварианту столбцов
  extra_columns_variants.each do |extra_columns|
    bt = matrix_without_columns(matrix, extra_columns).t

    # по каждому инварианту строк
    inner_extra_columns_variants.each do |inner_extra_columns|
      percent += step
      unless prev_percent == (percent / $any_percent).to_i
        puts "#{percent.round((1.0 / $any_percent).to_s.size)}%"
        prev_percent = (percent / $any_percent).to_i
      end

      # выделяем матрицу, и находим её определитель
      bt1 = matrix_without_columns(bt, inner_extra_columns)
      next if bt1.det == 0

      # определитель не равен нулю и поэтому производим "нехитрые" операции
      bt2 = matrix_with_columns(bt, inner_extra_columns)
      a = matrix_minus(bt2) * ident
      x = bt1.inverse * a
      final_x = build_final_x(x, inner_extra_columns)

      # запоминаем полученный вариант во множестве всех вариантов
      all_results << final_x
    end
  end

  all_results
end

# Содержит ли матрица дробные элементы
def consist_fractional?(matrix)
  matrix.to_a.each do |row|
    row.each do |num|
      return true unless num * 10 == (num * 10).to_i
    end
  end
  false
end

# Отчищает мтожество решений от решений с дробными элементами
def remote_fractional(set_of_results)
  arr_of_results = set_of_results.to_a
  (arr_of_results.size - 1).downto(0) do |i|
    arr_of_results.delete_at(i) if consist_fractional?(arr_of_results[i])
  end
  arr_of_results
end

# оОсновная функция
def main
  sm = source_matrix
  b_nb = sm[0]
  b_b = sm[1]
  separator = '-' * (b_nb.column_size + b_b.column_size + 1) * $range + "\n"

  # формируем строку, для вывода в выходной файл
  src_matrix_str = "Source matrix:\n"
  src_matrix_str << separator
  src_matrix_str << matrix_str(b_nb, b_b)
  src_matrix_str << separator
  src_matrix_str << "Rank of source Bodenshtain matrix: #{b_b.rank}\n\n"

  puts src_matrix_str
  $output.write(src_matrix_str)

  result_str = ''
  # проверяем, возможны ли инварианты
  if b_b.rank < b_b.column_size
    # находим решения
    all_solutions = find_all_solutions(b_b)
    puts "Was found #{all_solutions.size} possible solutions"
    # убираем повторяющиеся
    results = Set.new(all_solutions)
    puts "and only #{results.size} different solutions"
    # убираем с дробными элементами
    results = remote_fractional(results)
    puts "and #{results.size} solutions without fractional"
    result_str << "Results of calculations: #{results.size}\n\n"
    # выводим то что осталось в выходной файл
    results.each do |x_result|
      final_result = b_nb.t * x_result
      result_str << matrix_str(x_result, final_result, '>>')
      unless x_result == results.last
        # рисуем красивую "клюшку" в виде тирешек
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
require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.on('-f', '--file FILE', 'ASM file to assemble') { |f| options[:file] = f }
  opts.on('-t', '--test', 'Self test') { options[:test] = true }
end.parse!

#
# r0 ZR
# r1 config
# r2 PC lower
# r3
# r4
# r5 tos
# r6 acc
# r7 sp
#

# Encoding:
# c 1 bit register r5 - r6
# R 2 bit register r4 - r7
# r 3 bit register r0 - r7
# A accumulator
# n number 
INSTRUCTIONS = File.read("instructions")

class Instruction
  attr_reader :format, :encoding, :mnemonic, :arg_map

  ARG_TYPES = {
    'A' => :accumulator,
    'c' => :register1,
    'R' => :register2,
    'r' => :register3,
    'n' => :number,
  }

  @@instructions = Hash.new { |h, k| h[k] = [] }

  def format_parts
    format.scan(/\w+|\S/)
  end

  def find_arg(c)
    i = 0
    @internal_format.each do |p|
      if p.is_a? Symbol
        break if p == ARG_TYPES[c]
        i += 1
      end
    end
    i
  end

  def initialize(s)
    @format, @encoding = s.split(';').map(&:strip)
    @mnemonic = format.split.first

    @internal_format = format_parts.map do |p|
      ARG_TYPES[p] || p
    end

    @arg_map = []
    last_c = nil
    encoding.chars do |c|
      next if last_c == c
      next unless ARG_TYPES.include? c
      last_c = c

      @arg_map << find_arg(c)
    end

    @internal_encoding = encoding.split('+').map(&:strip)
  end

  def self.from_register(r)
    case r
    when /\Ar\d+\z/
      r[1..].to_i
    when 'config'
      1
    when 'tos'
      5
    when 'acc'
      6
    when 'sp'
      7
    else
      nil
    end
  end

  def match(s)
    parts = s.scan /\w+|\S/
    return nil unless parts.length == @internal_format.length
    registers = []
    @internal_format.each_with_index do |p, i|
      case p
      when :register1, :register2, :register3, :accumulator
        r = Instruction.from_register parts[i]
        return nil unless r
        case p
        when :accumulator
          return nil unless r == 6
        when :register1
          return nil unless (5..6) === r
        when :register2
          return nil unless (4..7) === r
        when :register3
          return nil unless (0..7) === r
        end

        registers << r
      when :number
        return nil unless parts[i] =~ /\A\d+\z/
        registers << parts[i].to_i
      else
        return nil unless parts[i] == p
      end
    end
    registers
  end

  def blit(arguments)
    i = 0
    @internal_encoding.map do |e|
      arg = arguments[arg_map[i]] rescue 0
      # puts "#{i}, #{arguments}, #{arg_map}, #{arg}"
      if e[0] != '#'
        v = Instruction.match(e.gsub(/\bn\b/, arg.to_s))
      else
        v = e[1..]
          .gsub('c',       (arg - 5).to_s(2).rjust(1, '0'))
          .gsub('RR',      (arg - 4).to_s(2).rjust(2, '0'))
          .gsub('rrr',     (arg    ).to_s(2).rjust(3, '0'))
          .gsub('nnnnnnn', (arg    ).to_s(2).rjust(7, '0'))
          .to_i(2)
      end
      i += 1
      v
    end.flatten
  end

  def to_s
    "Instruction(#{format}, #{encoding})"
  end

  def self.load(instruction_defs)
    instruction_defs.lines.each do |i|
      next if i.strip == ""
      instr = Instruction.new i
      @@instructions[instr.mnemonic.to_sym] << instr
    end
  end

  def self.match(s, instr: false)
    mnem = s.split.first.to_sym
    @@instructions[mnem].each do |i|
      r = i.match s
      return i if r and instr
      return i.blit(r) if r
    end
    STDERR.puts "WARNING: #{s} is not a valid instruction / encoding"
    []
  end
end

Instruction.load(INSTRUCTIONS)

def output(arr)
  arr.map { |i| i.to_s(2).rjust(8, '0') }
end

def check(example, correct)
  actual = Instruction.match(example)
  if actual != correct
    instr = Instruction.match(example, instr: true)
    puts "#{example} is wrong!"
    puts "  matched: #{instr}"
    puts "  got:     #{output actual}"
    puts "  wanted:  #{output correct}"
  else
    puts "#{example.ljust(20)} #{output(actual).inspect.ljust(40)} ✓"
  end
end

if options[:test]
  check "add r5, 4",        [0b1000_0100, 0b0100_1000]
  check "ld r6, [r7 + 10]", [0b1000_1010, 0b0101_0111]
  check "add acc",          [0b0000_0010]
  check "mov r5, acc",      [0b0010_0101]
  check "mov acc, r2",      [0b0010_1010]
  check "jmp 127",          [0b1111_1111, 0b0110_1000]
  check "jmp r7",           [0b0110_1100]
  check "rtn",              [0b0110_1010]
  check "jz 10",            [0b1000_1010, 0b0111_1000, 0b0110_1000]
  check "mov acc, sp",      [0b0010_1111]
  check "add r12",          []
end

if options[:file]
  puts File.read(options[:file])
    .lines
    .map(&:strip)
    .reject(&:empty?)
    .map { |l| Instruction.match(l) }
    .flatten
    .map { |l| l.to_s(16).rjust(2, '0') }
    .join(" ")
end

require "option_parser"

# require "tempfile"

module Coverage
  module CLI
    def self.run
      output_format = "HtmlReport"
      filenames = [] of String
      print_only = false

      OptionParser.parse do |parser|
        parser.banner = "Usage: crystal-coverage [options] <filename>"
        parser.on("-o FORMAT", "--output-format=FORMAT", "The output format used (default: HtmlReport): HtmlReport, Coveralls ") { |f| output_format = f }
        parser.on("-p", "--print-only", "output the generated source code") { |_p| print_only = true }
        parser.on("--use-require=REQUIRE", "change the require of cover library in runtime") { |r| Coverage::SourceFile.use_require = r }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit
        end
        parser.unknown_args do |args|
          args.each do
            filenames << ARGV.shift
          end
        end
      end

      filenames = Dir["spec/**/*_spec.cr"] if filenames.empty?

      Coverage::SourceFile.outputter = "Coverage::Outputter::#{output_format.camelcase}"

      write_source_io, read_source_io = IO::Stapled.pipe(read_blocking: true)

      spawn do
        write_source_io << Coverage::SourceFile.prelude_operations
        filenames.each do |f|
          v = Coverage::SourceFile.new(path: f, source: ::File.read(f))
          write_source_io << v.to_covered_source
          write_source_io << "\n"
        end
        write_source_io << Coverage::SourceFile.final_operations
      end

      if print_only
        puts read_source_io.to_s
      else
        Process.run(
          "crystal",
          {"eval"},
          input: read_source_io,
          output: :inherit,
          error: :inherit,
        ).success?
      end
    end
  end
end

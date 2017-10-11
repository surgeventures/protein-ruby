module Protein
class ProtoCompiler
  class << self
    def call(proto_directory: "./lib", namespace: nil)
      proto_files = Dir.glob("#{proto_directory}/**/*.proto")

      proto_files.each do |proto_file|
        puts "Compiling #{proto_file}"

        cmd_args = [
          "protoc",
          "-I", proto_directory,
          "--ruby_out", proto_directory,
          proto_file
        ]

        output = `#{cmd_args.shelljoin} 2>&1`

        unless $?.success?
          raise "Proto compilation failed:\n#{output}"
        end
      end

      rewrite_namespace(proto_directory, namespace) if namespace
    end

    private

    def rewrite_namespace(proto_directory, namespace)
      proto_files = Dir.glob("#{proto_directory}/**/*_pb.rb")

      proto_files.each do |proto_file|
        puts "Namespacing #{proto_file} to #{namespace}"

        old_content = File.read(proto_file)

        File.write(proto_file, "module #{namespace}\n#{old_content}\nend\n")
      end
    end
  end
end
end

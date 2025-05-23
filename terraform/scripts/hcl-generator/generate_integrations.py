import yaml
import sys
import hcl2
import os
import argparse
from pathlib import Path

OUTPUTS_TF_FILE = "outputs.tf"


def build_parser():
    """Create and configure the argument parser for the script."""

    parser = argparse.ArgumentParser(description="Process YAML and generate Terraform output.")
    
    parser.add_argument(
        '--input-yaml',
        required=True,
        help='Path to the input YAML file (charmcraft.yaml or metadata.yaml)'
    )
    
    parser.add_argument(
        '--outputs-tf', 
        default=OUTPUTS_TF_FILE,
        help=f'Path to the output Terraform file (default: {OUTPUTS_TF_FILE})'
    )
    
    return parser


class HCLGenerator(object):
    def __init__(self, input_yaml: str, outputs_tf: str):
        self.input_yaml = Path(input_yaml)
        if outputs_tf == OUTPUTS_TF_FILE:
            self.outputs_tf = Path(os.getcwd()) / outputs_tf
        else:
            self.outputs_tf = Path(outputs_tf)

    def parse_yaml(self):
        """Parse the YAML file and return the data"""
        try:
            with open(self.input_yaml, "r") as file:
                return yaml.safe_load(file)
        except Exception as e:
            print(f"Error reading YAML file: {e}")
            sys.exit(1)

    @staticmethod
    def format_keys(section):
        """
        Format the keys by replacing hyphens with underscores
        Although HCL allows dashes in keys, this does not allow for dot notation
        """
        return {key.replace("-", "_"): key for key in section}

    def create_file_with_parents(self):
        """Create the file and parent directories if they don't exist"""
        self.outputs_tf.parent.mkdir(parents=True, exist_ok=True)
        self.outputs_tf.touch(exist_ok=True)

    def generate_output(self, data):
        """Generate the output string based on the parsed YAML data"""
        requires = data.get("requires", {})
        provides = data.get("provides", {})

        # Format the keys in the 'requires' and 'provides' sections
        requires_formatted = self.format_keys(requires)
        provides_formatted = self.format_keys(provides)

        # Prepare the output string
        output = 'output "endpoints" {\n  value = {\n'

        # Add requires
        output += "    # Requires\n"
        for key, value in requires_formatted.items():
            output += f'    {key:<20} = "{value}",\n'

        # Add provides
        output += "    # Provides\n"
        for key, value in provides_formatted.items():
            output += f'    {key:<20} = "{value}",\n'

        output += "  }\n}"
        # TODO: Create a function for `terraform format` of the output
        return output

    def write_hcl_file(self, hcl_content):
        """Parse the YAML file and return the data"""
        
        self.create_file_with_parents()

        with open(self.outputs_tf, "r") as file:
            read_obj = hcl2.load(file)

        if read_obj:
            print("WE HAD CONTENTS")
        
        with open(self.outputs_tf, "w") as file:
            file.write(hcl_content)


def main():
    """Main function to handle script execution"""

    parser = build_parser()
    args = parser.parse_args()

    gen = HCLGenerator(args.input_yaml, args.outputs_tf)
    data = gen.parse_yaml()
    output_raw = gen.generate_output(data)
    print(output_raw)
    gen.write_hcl_file(output_raw)


if __name__ == "__main__":
    main()

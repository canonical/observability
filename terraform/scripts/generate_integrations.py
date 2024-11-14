import yaml
import sys


def parse_yaml(file_path):
    """Parse the YAML file and return the data"""
    with open(file_path, "r") as file:
        return yaml.safe_load(file)


def format_keys(section):
    """
    Format the keys by replacing hyphens with underscores
    Although HCL allows dashes in keys, this does not allow for dot notation
    """
    return {key.replace("-", "_"): key for key in section}


def generate_output(data):
    """Generate the output string based on the parsed YAML data"""
    requires = data.get("requires", {})
    provides = data.get("provides", {})

    # Format the keys in the 'requires' and 'provides' sections
    requires_formatted = format_keys(requires)
    provides_formatted = format_keys(provides)

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


def main():
    """Main function to handle script execution"""
    if len(sys.argv) < 2:
        print("Usage: python script.py <path_to_yaml>")
        sys.exit(1)

    yaml_file_path = sys.argv[1]

    # Parse the YAML file
    try:
        data = parse_yaml(yaml_file_path)
    except Exception as e:
        print(f"Error reading YAML file: {e}")
        sys.exit(1)

    # Generate the output and print it
    output = generate_output(data)
    print(output)


if __name__ == "__main__":
    main()

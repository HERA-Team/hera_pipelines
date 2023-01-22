import numpy as np
import yaml
import argparse

parser = argparse.ArgumentParser()

# add options for providing yaml and output file location

if __name__ == "__main__":
    args = parser.parse_args()
    with open(args.yaml_file, "r") as f:
        contents = yaml.load(f.read(), Loader=yaml.SafeLoader)

    ants = list(contents['ex_ants'])
    with open(args.outfile, "w") as f:
        outfile.write("\n".join(ants)

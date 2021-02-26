import numpy as np
import glob

freq_flags = [[100.0e6, 111e6], 
              [137e6, 138e6], 
              [187e6, 199.90234375e6]]

# TODO: load these from a csv rather than storing them here
JD_flags = {2458041: [[0.50, 0.70]], # from Josh's inspecting notebooks on 2/9/21
            2458049: [[0.10, 0.41]], # from Josh's inspecting notebooks on 2/9/21
            2458052: [[0.50, 0.90]], # from Josh's inspecting notebooks on 2/9/21
            2458054: [[0.10, 0.90]], # X-engine issues. Excluded whole day. From Josh's inspecting notebooks on 2/9/21
            2458055: [[0.10, 0.90]], # X-engine issues. Excluded whole day. From Josh's inspecting notebooks on 2/9/21
            2458056: [[0.10, 0.90]], # X-engine issues. Excluded whole day. From Josh's inspecting notebooks on 2/9/21
            2458058: [[0.10, 0.48]], # from Vignesh's by-hand analysis H1C IDR3.1, expanded by Josh on 2/9/21
            2458059: [[0.10, 0.48]], # from Vignesh's by-hand analysis H1C IDR3.1, expanded by Josh on 2/9/21
            2458061: [[0.10, 0.90]], # Broadband RFI issues. Excluded whole day. From Josh's inspecting notebooks on 2/9/21
            2458065: [[0.10, 0.90]], # Broadband RFI issues. Excluded whole day. From Josh's inspecting notebooks on 2/9/21
            2458066: [[0.10, 0.90]], # Broadband RFI issues. Excluded whole day. From Josh's inspecting notebooks on 2/9/21
            2458096: [[0.20, 0.40], 
                      [0.45, 0.50]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458104: [[0.20, 0.27],
                      [0.35, 0.45]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458109: [[0.20, 0.46]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458114: [[0.10, 0.32]], # flagged due to a broken X-engine 
            2458136: [[0.20, 0.36]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458140: [[0.27, 0.33],
                      [0.44, 0.47],
                      [0.50, 0.58],
                      [0.62, 0.70]], # added by Josh on 12/29/20
            2458141: [[0.30, 0.49],
                      [0.25, 0.29]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458148: [[0.20, 0.33]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458159: [[0.20, 0.50]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458161: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1. Excluded by Josh on inpsectiing notebooks 2/18/21
            2458172: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1. Excluded by Josh on inspecting notebooks 2/18/21
            2458173: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1. Excluded by Josh on inspecting notebooks 2/18/21
            2458185: [[0.10, 0.50]], # from Vignesh's by-hand analysis H1C IDR3.1. Expanded by Josh on inspecting notebooks 2/18/21
            2458206: [[0.20, 0.28]], # from Vignesh's by-hand analysis H1C IDR3.1
           }

def driver():
    bad_ants_files = sorted(glob.glob("./bad_ants/*.txt"))
    for baf in bad_ants_files:
        JD = int(baf.split('/')[-1].split('.txt')[0])
        bad_ants = np.loadtxt(baf).astype(int)
        with open(f'./a_priori_flags/{JD}.yaml', 'w+') as f:
            if JD in JD_flags:
                f.write(f'JD_flags: {[[flag + JD for flag in pair] for pair in JD_flags[JD]]}\n')
            f.write(f'freq_flags: {freq_flags}\n')
            f.write(f'ex_ants: [{", ".join([str(ba) for ba in bad_ants])}]\n')
    
if __name__ == "__main__":
    driver()

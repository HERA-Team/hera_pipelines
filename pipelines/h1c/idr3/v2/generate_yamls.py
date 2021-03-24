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
            2458085: [[0.56, 0.90]], # Broadband RFI in last hour or so. From Josh's inspecting notebooks on 2/25/21
            2458088: [[0.52, 0.90]], # Narrowband RFI in last few hours. From Josh's inspecting notebooks on 2/25/21
            2458089: [[0.10, 0.90]], # Narrowband RFI in last few hours. From Josh's inspecting notebooks on 2/25/21. Flagged completely due to smooth_cal issues discovered 3/11/21 by Josh
            2458090: [[0.50, 0.90]], # Narrowband RFI in last few hours. From Josh's inspecting notebooks on 2/26/21
            2458095: [[0.10, 0.30],
                      [0.49, 0.58]], # Broadband RFI in at start of night and late in the night. From Josh's inspecting notebooks on 2/26/21
            2458096: [[0.10, 0.52]], # from Vignesh's by-hand analysis H1C IDR3.1, expanded by Josh's notebook inspection on 2/26/21
            2458104: [[0.10, 0.47]], # from Vignesh's by-hand analysis H1C IDR3.1, expanded by Josh's notebook inspection on 2/26/21
            2458105: [[0.10, 0.43]], # Broadband RFI for first half of the night. From Josh's inspecting notebooks on 2/26/21
            2458109: [[0.20, 0.46]], # from Vignesh's by-hand analysis H1C IDR3.1
            2458110: [[0.47, 0.90]], # Narrowband RFI in last few hours. From Josh's inspecting notebooks on 2/26/21
            2458114: [[0.10, 0.32]], # flagged due to a broken X-engine 
            2458135: [[0.10, 0.43]], # flagged due to excess broadband RFI. From Josh's inspecting notebooks on 3/9/21
            2458136: [[0.20, 0.43]], # from Vignesh's by-hand analysis H1C IDR3.1, expanded from Josh's inspecting notebooks on 3/9/21
            2458139: [[0.10, 0.34]], # flagged due to excess broadband RFI. From Josh's inspecting notebooks on 3/9/21
            2458140: [[0.10, 0.90]], # added by Josh on 12/29/20, expanded to full day flag from Josh's inspecting notebooks on 3/9/21
            2458141: [[0.10, 0.52]], # from Vignesh's by-hand analysis H1C IDR3.1. Expanded from Josh's inspecting notebooks on 3/9/21
            2458144: [[0.10, 0.31]], # flagged due to excess broadband RFI. From Josh's inspecting notebooks on 3/9/21
            2458145: [[0.10, 0.38]], # flagged due to excess broadband RFI. From Josh's inspecting notebooks on 3/9/21
            2458148: [[0.10, 0.37]], # from Vignesh's by-hand analysis H1C IDR3.1. Expanded from Josh's inspecting notebooks on 3/9/21
            2458157: [[0.46, 0.90]], # Omnical issues, possibly non-convergence. From Josh's inspecting notebooks on 3/9/21
            2458159: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1, expanded to full day flag from Josh's inspecting notebooks on 3/9/21
            2458161: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1. Excluded by Josh on inpsectiing notebooks 2/18/21
            2458172: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1. Excluded by Josh on inspecting notebooks 2/18/21
            2458173: [[0.10, 0.90]], # from Vignesh's by-hand analysis H1C IDR3.1. Excluded by Josh on inspecting notebooks 2/18/21
            2458185: [[0.10, 0.52]], # from Vignesh's by-hand analysis H1C IDR3.1. Expanded by Josh on inspecting notebooks 2/18/21. Further expanded to .52 on 3/23/21.
            2458187: [[0.64, 0.90]], # Flag some galaxy to prevent smooth_cal issues found by Josh on inspecting notebooks on 3/23/21.
            2458187: [[0.64, 0.90]], # Flag some galaxy to prevent smooth_cal issues found by Josh on inspecting notebooks on 3/23/21.
            2458189: [[0.52, 0.90]], # Weak broadband RFI + flag some galaxy to prevent smooth_cal issues found by Josh on inspecting notebooks on 3/23/21.
            2458190: [[0.63, 0.90]], # Flag some galaxy to prevent smooth_cal issues found by Josh on inspecting notebooks on 3/23/21.
            2458192: [[0.10, 0.90]], # X-engine died, found by Josh on inspecting notebooks 3/23/21
            2458196: [[0.64, 0.90]], # Flag some galaxy to prevent smooth_cal issues found by Josh on inspecting notebooks on 3/23/21.
            2458199: [[0.10, 0.29]], # Broadband RFI early in night. Found by Josh on inspecting notebooks 3/23/21
            2458200: [[0.10, 0.26]], # Broadband RFI early in night. Found by Josh on inspecting notebooks 3/23/21
            2458201: [[0.64, 0.90]], # Flag some galaxy to prevent smooth_cal issues found by Josh on inspecting notebooks on 3/23/21.
            2458205: [[0.10, 0.28]], # Broadband RFI early in night. Found by Josh on inspecting notebooks 3/23/21
            2458206: [[0.10, 0.34]], # from Vignesh's by-hand analysis H1C IDR3.1. Expanded by Josh on inspecting notebooks 3/23/21
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

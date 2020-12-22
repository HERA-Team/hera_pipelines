import numpy as np
import glob, os
import pandas as pd


def write(jdflags):
    '''
    Writes the YAML files based on a csv file which contains the days of data
    and their corresponding JDflags. See write_csv for more details about that 
    file. 

    Args: 
        jdflags (str): path to the csv file containing the jd flags 
    '''
    antfiles=glob.glob("./bad_ants/*.txt")
    bad_ants=[]
    for file in antfiles:
        with open(file) as f:
            day=f.readlines()
        day=[int(ant.strip()) for ant in day]
        bad_ants.append(day)
    # jd flags
    data=pd.read_csv(jdflags)
    days=np.array(data['days']+2458000)
    jdflags=np.array(data['jdflags'])
    freqflags=[[100.0e6, 111e6], [137e6, 138e6], [187e6, 199.90234375e6]]
    # write
    for i in range(len(bad_ants)):
        fname='./a_priori_flags/'+str(days[i])+'.yaml'
        with open(fname,'w+') as f:
            f.write('JD_flags: {}'.format(jdflags[i])+"\n")
            f.write('freq_flags: {}'.format(freqflags)+"\n")
            f.write('ex_ants: {}'.format(bad_ants[i])+"\n")
    
    
def write_csv(days,good,bad,badflags=None,savename='jdflags.csv'):
    '''
    Writes a csv files consisting of the days of data and the corresponding JD flags
    
    Args:
        days (array-like): array consisting of the dates being analysed

        good (array-like): those days for which the data looks clean and 
                           no flags other than the default are required.  
        
        bad (array-like): those days for which flags other than the default are required
                          (for when there is partially sketchy data)

        savename (str): the name under which the csv is to be saved; the default
                        is flags.csv.

        badflags (array-like) : default set to none. array consisting of the dates and 
                                jd flags to apply to all the bad days. 

        
    '''
    days,bad,good=[int(i) for i in days],[int(i) for i in bad],[int(i) for i in good]
    df=pd.DataFrame({'days':good,'jdflags':None})
    for i in badflags:
        df.loc[len(df)]=i
    df.set_index('days',inplace=True)
    df.to_csv(savename)
    return savename



def driver():
    days=glob.glob("./bad_ants/*.txt")
    days=[(f[-7:-4]) for f in days]

    # bad is a hardcoded list of days with sketchy data
    bad=['058','059','096','104','109','136','140','141','148','159','161','172','173','185','206']

    good=[d for d in days if d not in bad]
    bad=[d for d in days if d in bad]

    # badflags is a hardcoded array of the sketchy days and extra JD ranges to be flagges
    badflags=np.array([[58,[[0.2,0.42]]],[59,[[0.2,0.45]]],[96,[[0.2,0.4],[0.45,0.5]]],[104,[[0.2,0.27],[0.35,0.45]]],[109,[[0.2,0.46]]],
        [136,[[0.2,0.36]]],[141,[[0.3,0.49],[0.25,0.29]]],[148,[[0.2,0.33]]],[159,[[0.2,0.5]]],[161,[[0.4,0.55]]],
        [172,[[0.2,0.58]]],[173,[[0.2,0.37],[0.4,0.5]]],[185,[[0.35,0.45]]],[206,[[0.2,0.28]]]],dtype='object')
    
    savename=write_csv(days,good,bad,badflags)
    write(savename)
    
if __name__ == "__main__":
    driver()

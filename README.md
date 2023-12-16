Our design is RISC-V P6 out-of-order pipeline design. 

## High-Level Design
**![High-Level Design](https://lh7-us.googleusercontent.com/pbSc6QUjMZyxU0h1h3ovbTgPTToeG0Uwtekv2FhLlg04htBpSnD0n6pu0CAZ37MfAXkuwADIexx7XAUBTNC71SR61ncZKBZoNcj4cAArN2LvrkGNDpNd-6VAlFEQZk-dq3HDArTE5Z9y2LW6NySadcM)**


## Advanced Features
We implemented 9 advanced features including 1 difficult and 8 simpler features:
1. 3-way Superscalar execution
2. A Load-Store Queue (LSQ)
3. Store to load forwarding in LSQ    
4. A pattern history table in Branch Predictor (PHT)
5. A branch history table in Branch Predictor (BHT)
6. A return address stack in Branch Predictor (RAS)
7. Instruction prefetching in Instruction Cache (ICache)
8. 2-way Associative Data Cache (DCache)
9. Non-blocking DCache with MSHR

## CPI 
![CPI-Test](https://lh7-us.googleusercontent.com/O8WAOtOHui9PBAzrzszn-t3345Upa2k3DbFcFQkOE3l5_aFFr41ryTpQvzQYb0JVgVykFFxjdRPJ-CDbx7T0db8FVP5XKBQx846KAf4rC1vNS8dhxWjQKgaiOiQ9cBnma2lHouBiXXQSz7FGsVmZCbw)

(P.S. 最后最后，我们的LSQ由清华大学的优秀毕业生亲自操刀，他表示是小学奥数，看不懂的都是废物)

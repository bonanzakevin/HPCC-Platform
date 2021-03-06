/*##############################################################################

    HPCC SYSTEMS software Copyright (C) 2012 HPCC Systems®.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
############################################################################## */

stepRecord :=
            record
string          next{maxlength(20)};
unsigned        leftStep;
unsigned        rightStep;
            end;


stateRecord :=
            record
unsigned        step;
unsigned        docid;  //dummy field
unsigned        value;
            end;

mkValue(unsigned value) := transform(stepRecord, self.next := (string)value; self := []);
mkOp(string1 op, unsigned l, unsigned r = 0) := transform(stepRecord, self.next := op; self.leftStep := l; self.rightStep := r);

mkState(unsigned step, unsigned value, unsigned docid = 1) := transform(stateRecord, self.step := step; self.docid := docid; self.value := value);

processExpression(dataset(stepRecord) actions) := function

    processNext(set of dataset(stateRecord) in, unsigned thisStep, stepRecord action) := function
        thisLeft := in[action.leftStep];
        thisRight := in[action.rightStep];


        result := case(action.next,
                           '+'=>join(sorted(thisLeft, docid), sorted(thisRight, docid), left.docid = right.docid,
                                     mkState(thisStep, left.value + right.value, left.docid)),
                           '-'=>join(sorted(thisLeft, docid), sorted(thisRight, docid), left.docid = right.docid,
                                     mkState(thisStep, left.value - right.value, left.docid)),
                           '*'=>join(sorted(thisLeft, docid), sorted(thisRight, docid), left.docid = right.docid,
                                     mkState(thisStep, left.value * right.value, left.docid)),
                           '/'=>join(sorted(thisLeft, docid), sorted(thisRight, docid), left.docid = right.docid,
                                     mkState(thisStep, left.value / right.value, left.docid)),
                           '~'=>project(thisLeft, mkState(thisStep, -left.value, left.docid)),
                           //make two rows for the default action, to ensure that join is grouping correctly.
                           dataset([mkState(thisStep, (unsigned)action.next), mkState(thisStep, (unsigned)action.next*10, 2)]));

        return result;
    END;

    initial := dataset([], stateRecord);
    result := GRAPH(initial, count(actions), processNext(rowset(left), counter, actions[NOBOUNDCHECK counter]), parallel);
    return result;
end;

actions := dataset([mkValue(10), mkValue(20), mkOp('*', 1, 2),
                    mkValue(15), mkValue(10), mkOp('+', 4, 5), mkOp('~', 6), mkOp('-', 3, 7)]);
output(processExpression(global(actions,few)));

/*
 * A backend boilerplate with example apis
 *
 * Copyright (C) 2018  Adam van der Kruk aka TacB0sS
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
	testExampleApi
} from "../blocks/api";
import {__scenario} from "@nu-art/test/Testelot";

let S;
export const TestApi = S = __scenario("Test Example Api");
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());
S.addSteps(testExampleApi());



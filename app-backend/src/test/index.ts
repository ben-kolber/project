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

import {__scenario} from "@nu-art/test/Testelot";
import {
	endServer,
	startServer
} from "./blocks/common";
import {
	ErrorPolicy,
	Reporter
} from "@nu-art/test";
import {BeLogged} from "@nu-art/core";
import {TestApi} from "./tests/example-api";

const reporter = new Reporter();
reporter.init();

(async () => {
	const root = __scenario("root", reporter);
	// root.addSteps(startServer(require("../../.config-test.json")).setErrorPolicy(ErrorPolicy.HaltOnError));
	root.addSteps(TestApi);
	root.addSteps(endServer().setLabel("terminatssing server"));

// @ts-ignore
	await root.run();
	BeLogged.clearFooter();
})();
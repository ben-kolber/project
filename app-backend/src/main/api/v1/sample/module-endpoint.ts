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
	ApiResponse,
	ServerApi_Get,
} from "@nu-art/server/HttpServer";

import * as express from "express";
import {ParsedUrlQuery} from "querystring";
import {ExampleModule} from "@modules/ExampleModule";

class ServerApi_EndpointExample
	extends ServerApi_Get {

	constructor() {
		super("endpoint-example");
	}

	protected async process(request: express.Request, response: ApiResponse, queryParams: ParsedUrlQuery, body: void) {
		response.text(200, ExampleModule.getRandomString());
	}
}

module.exports = new ServerApi_EndpointExample();

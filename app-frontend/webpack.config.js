/*
 * A typescript & react boilerplate with api call example
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

const path = require('path');
const HtmlWebPackPlugin = require("html-webpack-plugin");
const WebpackMd5Hash = require('webpack-md5-hash');
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CleanWebpackPlugin = require('clean-webpack-plugin');
const WriteFilePlugin = require('write-file-webpack-plugin');
const sourcePath = path.join(__dirname, './src');

module.exports = (env, argv) => {

	const envConfig = require(`./_config/${env}`);

	console.log("env: " + env);
	console.log("argv: " + JSON.stringify(argv));
	console.log("argv.mode: " + argv.mode);
	const outputFolder = path.resolve(__dirname, `dist/${envConfig.outputFolder()}`);

	return {
		context: sourcePath,
		entry: {
			main: './main/index.tsx',
		},
		output: {
			path: outputFolder,
			filename: '[name].[chunkhash].js',
			publicPath: '/',
		},
		devtool: "source-map",

		devServer: {
			historyApiFallback: true,
			compress: true,
			https: !argv.ssl ? undefined : envConfig.getDevServerSSL(),
			port: envConfig.getHostingPort(),
		},

		resolve: {
			alias: {
				"@modules": path.resolve(__dirname, "src/main/modules"),
				"@consts": path.resolve(__dirname, "src/main/consts"),
				"@components": path.resolve(__dirname, "src/main/components"),
				"@renderers": path.resolve(__dirname, "src/main/renderers"),
				"@shared": path.resolve(__dirname, "src/main/app-shared"),
				// "@utils": path.resolve(__dirname, "src/main/utils")
			},
			extensions: ['.js', '.jsx', '.json', '.ts', '.tsx']
		},

		module: {
			rules: [
				{test: /\.tsx?$/, loader: "awesome-typescript-loader", exclude: [/node_modules/, /dist/]},
				{enforce: "pre", test: /\.js$/, loader: "source-map-loader", exclude: [/node_modules/, /dist/, /build/, /__test__/]},
				{
					test: /\.[ot]tf$/,
					use: [
						{
							loader: 'url-loader',
							options: {
								limit: 10000,
								mimetype: 'application/octet-stream',
								name: 'fonts/[name].[ext]',
							}
						}
					]
				},
				{
					test: /\.json$/,
					exclude: /node_modules/,
					use: {
						loader: "file-loader",
					}
				},
				{
					test: /\.(jpe?g|png|gif|ico)$/i,
					use: [
						{
							loader: 'file-loader',
							options: {
								regExp: /\/src\/main\/res\/images\/(.*\.png)$/,
								name: 'images/[1]',
							}
						},
					]
				},
				{
					test: /\.s?[c|a]ss$/,
					use: [
						'style-loader',
						MiniCssExtractPlugin.loader,
						{
							loader: 'css-loader',
							options: {minimize: envConfig.cssMinify(), importLoaders: 2}
						},
						{
							loader: 'postcss-loader',
							options: {
								plugins: () => [
									require('autoprefixer')
								],
							}
						},
						'sass-loader'
					]
				}
			]
		},
		plugins: [
			new CleanWebpackPlugin(outputFolder),
			new MiniCssExtractPlugin({
				filename: 'main/res/styles.[contenthash].css',
			}),
			new HtmlWebPackPlugin({
				inject: true,
				favicon: './main/res/favicon.ico',
				template: "./main/index.ejs",
				filename: "./index.html",
				minify: envConfig.htmlMinificationOptions(),
			}),
			new WebpackMd5Hash(),
			envConfig.getPrettifierPlugin(),
			new WriteFilePlugin(),
		].filter(plugin => plugin),

	};
};

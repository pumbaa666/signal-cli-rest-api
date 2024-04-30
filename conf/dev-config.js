const conf = {
	http: {
		port: 8080
	},
		
	signalCli: {
		command: 'docker',
		args: ['run', 'signal-cli', '-v']
	}
};

module.exports = conf;

FROM node:16.18

ENV PORT=3000

COPY . /frontend-react-js
WORKDIR /frontend-react-js
RUN npm install
EXPOSE ${PORT}
# RUN chown -R node node_modules
# USER node
CMD ["npm", "start"]